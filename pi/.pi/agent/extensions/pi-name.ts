/**
 * pi-name — names a running pi agent instance and exposes a local bridge
 * socket so external clients (the Neovim connector) can talk to it.
 *
 * Name resolution (first wins):
 *   1. --pi-name <name>   CLI flag (registered by this extension)
 *   2. $PI_NAME           environment variable
 *   3. basename(cwd)
 *
 * TUI sessions only: starts a JSONL server on ~/.pi/agent/pi-name/<name>.sock
 * and also names the session (pi.setSessionName), so the instance is
 * recognizable in `pi -r` as well. rpc/print/json modes never start the
 * server, so ephemeral `pi --mode rpc` jobs do not pollute the registry.
 *
 * Protocol (one JSON object per line):
 *   client -> server:
 *     {"cmd":"hello"}
 *     {"cmd":"prompt","message":"...","deliverAs":"steer"|"followUp"}
 *     {"cmd":"abort"}
 *     {"cmd":"close"}
 *   server -> client:
 *     {"type":"hello","name","cwd","model","busy","sessionName"}
 *     {"type":"response","command","success":true}
 *     {"type":"error","message"}
 *     {"type":"agent_start" | "agent_end" | "message_start" | ...}
 *       (same shapes as `pi --mode rpc` events, compacted)
 *
 * One client at a time; a second connection is rejected with
 * {"type":"error","message":"client attached"}.
 */
import { createServer, type Server, type Socket } from "node:net";
import { existsSync, mkdirSync, rmSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const NAME_DIR = join(homedir(), ".pi", "agent", "pi-name");
const FORWARDED = [
  "agent_start",
  "agent_end",
  "message_start",
  "message_update",
  "message_end",
  "tool_execution_start",
  "tool_execution_end",
];

function sanitize(name: string): string {
  return name.replace(/[^A-Za-z0-9._-]/g, "-") || "unnamed";
}

export default function (pi: ExtensionAPI) {
  pi.registerFlag("pi-name", {
    description: "Instance name for external clients (Neovim connector); default: $PI_NAME or the working directory name",
    type: "string",
    default: "",
  });

  let server: Server | null = null;
  let client: Socket | null = null;
  let socketPath = "";
  let ctxRef: any = null;
  let displayName = "";

  function write(sock: Socket, obj: unknown) {
    if (!sock.destroyed) {
      sock.write(JSON.stringify(obj) + "\n");
    }
  }

  function helloPayload() {
    const ctx = ctxRef;
    const model = ctx?.model;
    return {
      type: "hello",
      name: displayName,
      cwd: ctx?.cwd ?? "",
      model: model ? `${model.provider}/${model.id}` : "unknown",
      busy: ctx ? !ctx.isIdle() || ctx.hasPendingMessages() : false,
      sessionName: pi.getSessionName() ?? displayName,
    };
  }

  function handleCommand(cmd: any) {
    const ctx = ctxRef;
    if (!ctx || !client) return;
    switch (cmd.cmd) {
      case "hello":
        write(client, helloPayload());
        break;
      case "prompt": {
        const message = typeof cmd.message === "string" ? cmd.message : String(cmd.message ?? "");
        if (!message) {
          write(client, { type: "error", message: "empty message" });
          return;
        }
        const deliverAs = cmd.deliverAs === "followUp" ? "followUp" : cmd.deliverAs === "steer" ? "steer" : undefined;
        try {
          const result = pi.sendUserMessage(message, deliverAs ? { deliverAs } : {});
          if (result && typeof (result as any).catch === "function") {
            (result as Promise<void>).catch((e: any) =>
              write(client, { type: "error", message: String(e?.message ?? e) }),
            );
          }
          write(client, { type: "response", command: "prompt", success: true });
        } catch (e: any) {
          write(client, { type: "error", message: String(e?.message ?? e) });
        }
        break;
      }
      case "abort":
        try {
          ctx.abort();
          write(client, { type: "response", command: "abort", success: true });
        } catch (e: any) {
          write(client, { type: "error", message: String(e?.message ?? e) });
        }
        break;
      case "close":
        write(client, { type: "response", command: "close", success: true });
        client.end();
        break;
      default:
        write(client, { type: "error", message: `unknown command: ${String(cmd.cmd)}` });
    }
  }

  function forward(event: any) {
    if (!client || client.destroyed) return;
    let out: any;
    switch (event.type) {
      case "agent_start":
        out = { type: "agent_start" };
        break;
      case "agent_end":
        out = { type: "agent_end" };
        break;
      case "message_start":
        out = { type: "message_start", message: { role: event.message?.role } };
        break;
      case "message_update":
        out = { type: "message_update", assistantMessageEvent: event.assistantMessageEvent };
        break;
      case "message_end":
        out = { type: "message_end", message: event.message };
        break;
      case "tool_execution_start":
        out = { type: "tool_execution_start", toolName: event.toolName, args: event.args };
        break;
      case "tool_execution_end":
        out = { type: "tool_execution_end", toolName: event.toolName, isError: event.isError };
        break;
      default:
        return;
    }
    write(client, out);
  }

  function onConnection(sock: Socket) {
    if (client) {
      write(sock, { type: "error", message: "client attached" });
      sock.end();
      return;
    }
    client = sock;
    let buf = "";
    sock.on("data", (chunk: Buffer) => {
      buf += chunk.toString("utf8");
      let idx: number;
      while ((idx = buf.indexOf("\n")) >= 0) {
        const line = buf.slice(0, idx).replace(/\r$/, "");
        buf = buf.slice(idx + 1);
        if (!line.trim()) continue;
        let cmd: any;
        try {
          cmd = JSON.parse(line);
        } catch {
          write(sock, { type: "error", message: "invalid JSON" });
          continue;
        }
        try {
          handleCommand(cmd);
        } catch (e: any) {
          write(sock, { type: "error", message: String(e?.message ?? e) });
        }
      }
    });
    const drop = () => {
      if (client === sock) client = null;
    };
    sock.on("close", drop);
    sock.on("error", drop);
  }

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    const raw =
      (pi.getFlag("pi-name") as string | undefined) || process.env.PI_NAME || basename(ctx.cwd);
    ctxRef = ctx;
    if (server) {
      // Session switched inside the same instance: keep the bridge, refresh name.
      displayName = raw;
      try {
        pi.setSessionName(raw);
      } catch {
        // cosmetic; ignore
      }
      return;
    }
    displayName = raw;
    try {
      pi.setSessionName(raw);
    } catch {
      // cosmetic; ignore
    }

    socketPath = join(NAME_DIR, `${sanitize(raw)}.sock`);
    try {
      mkdirSync(NAME_DIR, { recursive: true, mode: 0o700 });
      if (existsSync(socketPath)) rmSync(socketPath);
    } catch {
      return; // cannot create the registry dir; skip the bridge silently
    }
    try {
      server = createServer(onConnection);
      server.on("error", (e: any) => {
        if (e?.code === "EADDRINUSE" || e?.code === "EEXIST") {
          ctx.ui.notify(`pi-name: name "${raw}" is already in use`, "warning");
        }
        server = null;
      });
      server.listen(socketPath);
    } catch {
      server = null;
    }

    for (const evt of FORWARDED) {
      (pi.on as any)(evt, (e: any) => forward(e));
    }
  });

  pi.on("session_shutdown", () => {
    if (client) {
      client.destroy();
      client = null;
    }
    if (server) {
      server.close();
      server = null;
    }
    if (socketPath) {
      try {
        if (existsSync(socketPath)) rmSync(socketPath);
      } catch {
        // stale socket; leave it, it will be cleaned by the next launch
      }
      socketPath = "";
    }
  });
}
