#!/usr/bin/env python3
"""
Archive PI agent and OpenCode sessions to NAS (Silo) or local backups.
Full dump format: JSONL/JSON → Markdown with all message types, tool calls, thinking blocks, usage stats.
"""

import json
import os
import glob
import subprocess
import sys
import time
import math
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

# --- Config ---
SILO_MOUNT = "/home/serhii/Silo"
BACKUP_DIR = Path.home() / "backups" / "archives"
PI_SESSIONS = Path.home() / ".pi" / "agent" / "sessions"
OC_STORAGE = Path.home() / ".local" / "share" / "opencode" / "storage"
MANIFEST_NAME = ".exported-sessions.json"

# --- Helpers ---

def is_silo_mounted() -> bool:
    """Check if Silo NAS is mounted and accessible (not just stale mount)."""
    try:
        # Check mount
        result = subprocess.run(
            ["mountpoint", "-q", SILO_MOUNT],
            capture_output=True, timeout=5
        )
        if result.returncode != 0:
            return False
        # Test actual I/O — stale NFS mounts pass mountpoint but fail writes
        test_file = Path(SILO_MOUNT) / ".archive-test"
        with open(test_file, "w") as f:
            f.write("test")
        test_file.unlink()
        return True
    except Exception:
        return False


def get_target_dir() -> Path:
    """Return target archive directory (Silo or fallback)."""
    if is_silo_mounted():
        return Path(SILO_MOUNT) / "archives"
    return BACKUP_DIR


def notify(title: str, message: str, urgency: str = "normal", icon: str = "drive-harddisk"):
    """Send desktop notification."""
    try:
        subprocess.run(
            ["notify-send", "-u", urgency, "-i", icon, title, message],
            capture_output=True, timeout=5
        )
    except Exception:
        pass


def load_manifest(target: Path) -> dict:
    """Load export manifest from target directory."""
    manifest_file = target / MANIFEST_NAME
    try:
        if manifest_file.exists():
            with open(manifest_file, "r") as f:
                return json.load(f)
    except OSError:  # NFS host down, stale mount
        pass
    return {"pi": {}, "opencode": {}}


def save_manifest(target: Path, manifest: dict):
    """Save export manifest to target directory."""
    manifest_file = target / MANIFEST_NAME
    try:
        manifest_file.parent.mkdir(parents=True, exist_ok=True)
        with open(manifest_file, "w") as f:
            json.dump(manifest, f, indent=2)
    except OSError as e:
        print(f"Warning: Cannot save manifest to {target}: {e}", file=sys.stderr)


def safe_name(name: str) -> str:
    """Sanitize a path component."""
    return name.replace("/", "_").replace("\\", "_").replace("..", "_")


def ts_to_iso(ts_ms: float) -> str:
    """Convert millisecond timestamp to ISO string."""
    return datetime.fromtimestamp(ts_ms / 1000, tz=timezone.utc).isoformat()


def ts_to_date(ts_ms: float) -> str:
    """Convert millisecond timestamp to YYYY-MM."""
    return datetime.fromtimestamp(ts_ms / 1000, tz=timezone.utc).strftime("%Y-%m")


# --- PI Session Export ---

def export_pi_session(session_file: Path, target: Path, manifest: dict) -> bool:
    """Export a single PI session (.jsonl) to .md. Returns True if exported."""
    try:
        session_data = []
        with open(session_file, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        session_data.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass

        if not session_data:
            return False

        # Session header
        header = session_data[0] if session_data else {}
        session_id = header.get("id", "unknown")
        session_ts = header.get("timestamp", "")
        cwd = header.get("cwd", "")
        version = header.get("version", "?")

        # Find latest message timestamp
        latest_ts = 0
        for entry in session_data:
            entry_ts = entry.get("timestamp", "")
            if isinstance(entry_ts, str):
                try:
                    dt = datetime.fromisoformat(entry_ts.replace("Z", "+00:00"))
                    latest_ts = max(latest_ts, dt.timestamp() * 1000)
                except Exception:
                    pass

        # Build output path first (needed for existence check)
        date_str = ts_to_date(latest_ts) if latest_ts else datetime.now().strftime("%Y-%m")
        out_dir = target / date_str / "pi" / safe_name(cwd)
        out_dir.mkdir(parents=True, exist_ok=True)

        out_file = out_dir / f"{session_file.name.replace('.jsonl', '')}.md"

        # Check incremental: skip only if file exists AND no new messages
        manifest_key = f"{cwd}--{session_file.name}"
        last_export = manifest["pi"].get(manifest_key, 0)
        if out_file.exists() and latest_ts <= last_export:
            return False  # Already exported, no new messages
        # If file doesn't exist (was moved/deleted), re-export even if manifest says exported

        lines = []
        lines.append(f"# PI Session: {session_id}")
        lines.append(f"\n**Source**: pi | **ID**: {session_id} | **Version**: v{version}")
        lines.append(f"**Date**: {session_ts} | **CWD**: {cwd}\n")
        lines.append("---\n")

        # Track model for display
        current_model = None
        current_provider = None

        for entry in session_data:
            entry_type = entry.get("type", "")

            if entry_type == "session":
                continue  # Already in header

            elif entry_type == "model_change":
                current_provider = entry.get("provider", "?")
                current_model = entry.get("modelId", "?")
                lines.append(f"\n> Model: `{current_model}` on `{current_provider}`")

            elif entry_type == "thinking_level_change":
                level = entry.get("thinkingLevel", "?")
                lines.append(f"\n> Thinking level: `{level}`")

            elif entry_type == "custom":
                custom_type = entry.get("customType", "")
                data = entry.get("data", {})
                lines.append(f"\n### Custom Event: `{custom_type}`")
                lines.append(f"```json\n{json.dumps(data, indent=2, ensure_ascii=False)}\n```")

            elif entry_type == "message":
                msg = entry.get("message", {})
                role = msg.get("role", "unknown")
                content_list = msg.get("content", [])

                # API / model info
                api_info = msg.get("api", "") or msg.get("provider", "")
                model_info = msg.get("model", "") or current_model
                usage = msg.get("usage", {})

                if role == "user":
                    lines.append(f"\n## User")
                    for block in content_list:
                        if isinstance(block, str):
                            lines.append(f"\n{block}")
                        elif isinstance(block, dict):
                            block_type = block.get("type", "")
                            if block_type == "text":
                                lines.append(f"\n{block.get('text', '')}")
                            elif block_type == "image_url":
                                lines.append(f"\n![image]({block.get('image_url', {}).get('url', '')})")
                            else:
                                lines.append(f"\n```json\n{json.dumps(block, indent=2, ensure_ascii=False)}\n```")

                elif role == "assistant":
                    header_parts = []
                    if model_info:
                        header_parts.append(f"model: `{model_info}`")
                    if usage:
                        tokens = usage.get("tokens", usage)
                        inp = tokens.get("input", "?")
                        out = tokens.get("output", "?")
                        cache_read = tokens.get("cacheRead", 0)
                        cache_write = tokens.get("cacheWrite", 0)
                        header_parts.append(f"tokens: {inp}in/{out}out")
                        if cache_read or cache_write:
                            header_parts.append(f"cache: {cache_read}r/{cache_write}w")
                    stop = msg.get("stopReason", "")
                    if stop:
                        header_parts.append(f"finish: `{stop}`")
                    cost = usage.get("cost", {})
                    if cost and cost.get("total", 0) > 0:
                        header_parts.append(f"cost: ${cost.get('total', 0):.6f}")

                    lines.append(f"\n## Assistant ({', '.join(header_parts)})")

                    for block in content_list:
                        if isinstance(block, str):
                            lines.append(f"\n{block}")
                        elif isinstance(block, dict):
                            block_type = block.get("type", "")
                            if block_type == "thinking":
                                thinking_text = block.get("thinking", "")
                                sig = block.get("thinkingSignature", "")
                                if thinking_text:
                                    lines.append(f"\n### Reasoning")
                                    lines.append(f"```thinking\n{thinking_text}\n```")
                            elif block_type == "text":
                                text = block.get("text", "")
                                if text:
                                    lines.append(f"\n{text}")
                            elif block_type == "tool_use":
                                tool_name = block.get("name", "unknown")
                                tool_input = block.get("input", {})
                                tool_id = block.get("id", "")
                                lines.append(f"\n### Tool Call: `{tool_name}` (id: {tool_id})")
                                lines.append(f"```json\n{json.dumps(tool_input, indent=2, ensure_ascii=False)}\n```")
                            elif block_type == "tool_result":
                                tool_id = block.get("toolUseId", "")
                                content_text = block.get("content", "")
                                lines.append(f"\n### Tool Result: `{tool_id}`")
                                if isinstance(content_text, list):
                                    for c in content_text:
                                        if isinstance(c, dict) and c.get("type") == "text":
                                            lines.append(f"\n{c.get('text', '')}")
                                        elif isinstance(c, str):
                                            lines.append(f"\n{c}")
                                elif isinstance(content_text, str):
                                    lines.append(f"\n{content_text}")
                            else:
                                lines.append(f"\n```json\n{json.dumps(block, indent=2, ensure_ascii=False)}\n```")

                elif role == "system":
                    lines.append(f"\n## System")
                    for block in content_list:
                        if isinstance(block, str):
                            lines.append(f"\n{block}")
                        elif isinstance(block, dict):
                            if block.get("type") == "text":
                                lines.append(f"\n{block.get('text', '')}")

            elif entry_type == "tool_response":
                tool_name = entry.get("toolName", "unknown")
                lines.append(f"\n### Tool Response: `{tool_name}`")
                content = entry.get("content", "")
                if isinstance(content, str):
                    lines.append(f"\n{content}")
                elif isinstance(content, list):
                    lines.append(f"```json\n{json.dumps(content, indent=2, ensure_ascii=False)}\n```")

            elif entry_type == "compact":
                lines.append(f"\n> ⚠ Session compacted (context trimmed)")

            elif entry_type == "summary":
                lines.append(f"\n### Summary")
                text = entry.get("text", "")
                if text:
                    lines.append(f"\n{text}")

            else:
                # Unknown type — dump as JSON
                lines.append(f"\n### Event: `{entry_type}`")
                lines.append(f"```json\n{json.dumps(entry, indent=2, ensure_ascii=False)}\n```")

        # Write file
        md_content = "\n".join(lines) + "\n"
        with open(out_file, "w", encoding="utf-8") as f:
            f.write(md_content)

        # Update manifest
        manifest["pi"][manifest_key] = latest_ts
        return True

    except Exception as e:
        print(f"Error exporting PI session {session_file}: {e}", file=sys.stderr)
        return False


# --- OpenCode Session Export ---

def export_opencode_session(meta_file: Path, target: Path, manifest: dict) -> bool:
    """Export a single OpenCode session to .md. Returns True if exported."""
    try:
        # Session metadata
        with open(meta_file, "r") as f:
            ses_meta = json.load(f)

        ses_id = ses_meta.get("id", "unknown")
        title = ses_meta.get("title", "Untitled")
        directory = ses_meta.get("directory", "")
        created = ses_meta.get("time", {}).get("created", 0)
        updated = ses_meta.get("time", {}).get("updated", 0)
        version = ses_meta.get("version", "?")
        project_id = ses_meta.get("projectID", "?")

        # Build output path first (needed for existence check)
        date_str = ts_to_date(updated) if updated > 0 else datetime.now().strftime("%Y-%m")
        project_name = safe_name(directory.split("/")[-1] if directory else "unknown")
        out_dir = target / date_str / "opencode" / project_name
        out_dir.mkdir(parents=True, exist_ok=True)

        out_file = out_dir / f"{ses_id}.md"

        # Check incremental: skip only if file exists AND no new messages
        last_export = manifest["opencode"].get(ses_id, 0)
        if updated <= last_export and out_file.exists():
            return False  # Already exported, file exists
        # If file doesn't exist (was moved/deleted), re-export even if manifest says exported

        # Load messages
        msg_dir = OC_STORAGE / "message" / ses_id
        if not msg_dir.exists():
            return False

        messages = []
        for msg_file in sorted(msg_dir.glob("*.json")):
            try:
                with open(msg_file, "r") as f:
                    msg_data = json.load(f)
                messages.append(msg_data)
            except Exception:
                continue

        if not messages:
            return False

        # Find latest timestamp
        latest_ts = updated
        for msg in messages:
            t = msg.get("time", {})
            created_t = t.get("created", 0)
            completed_t = t.get("completed", 0)
            latest_ts = max(latest_ts, created_t, completed_t)

        # Re-check: skip only if file exists AND no new messages
        if out_file.exists() and latest_ts <= last_export:
            return False

        lines = []
        lines.append(f"# OpenCode Session: {title}")
        lines.append(f"\n**Source**: opencode | **ID**: {ses_id} | **Version**: v{version}")
        lines.append(f"**Project**: {directory}")
        lines.append(f"**Created**: {ts_to_iso(created) if created else '?'}")
        lines.append(f"**Updated**: {ts_to_iso(updated) if updated else '?'}\n")
        lines.append("---\n")

        # Process each message
        for msg in messages:
            role = msg.get("role", "unknown")
            msg_id = msg.get("id", "unknown")
            mode = msg.get("mode", "")
            model_id = msg.get("modelID", "")
            provider_id = msg.get("providerID", "")
            tokens = msg.get("tokens", {})
            cost = msg.get("cost", 0)
            finish = msg.get("finish", "")
            parent_id = msg.get("parentID", "")

            # Load message parts
            parts_dir = OC_STORAGE / "part" / msg_id
            parts = []
            if parts_dir.exists():
                for part_file in sorted(parts_dir.glob("*.json")):
                    try:
                        with open(part_file, "r") as f:
                            part_data = json.load(f)
                        parts.append(part_data)
                    except Exception:
                        continue

            # Sort parts by time
            parts.sort(key=lambda p: p.get("time", {}).get("start", 0))

            if role == "user":
                # User messages: parts have type=text
                lines.append(f"\n## User")
                user_cwd = msg.get("path", {}).get("cwd", "")
                if user_cwd:
                    lines.append(f"*CWD: {user_cwd}*")

                for part in parts:
                    if part.get("type") == "text":
                        text = part.get("text", "")
                        if text:
                            lines.append(f"\n{text}")
                # Also show summary if present
                summary = msg.get("summary", {})
                if summary and not parts:
                    summary_title = summary.get("title", "")
                    if summary_title:
                        lines.append(f"\n{summary_title}")

            elif role == "assistant":
                # Build header
                header_parts = []
                if model_id:
                    header_parts.append(f"model: `{model_id}`")
                if provider_id:
                    header_parts.append(f"provider: `{provider_id}`")
                if mode:
                    header_parts.append(f"mode: `{mode}`")

                inp = tokens.get("input", 0)
                out = tokens.get("output", 0)
                reasoning = tokens.get("reasoning", 0)
                cache = tokens.get("cache", {})
                if inp or out:
                    header_parts.append(f"tokens: {inp}in/{out}out")
                    if reasoning:
                        header_parts.append(f"reasoning: {reasoning}")
                    if cache.get("read", 0):
                        header_parts.append(f"cache: {cache.get('read', 0)}r/{cache.get('write', 0)}w")
                if cost and cost > 0:
                    header_parts.append(f"cost: ${cost:.6f}")
                if finish:
                    header_parts.append(f"finish: `{finish}`")

                lines.append(f"\n## Assistant ({', '.join(header_parts)})")

                for part in parts:
                    part_type = part.get("type", "")
                    if part_type == "text":
                        text = part.get("text", "")
                        if text:
                            lines.append(f"\n{text}")
                    elif part_type == "tool":
                        tool_name = part.get("tool", "unknown")
                        tool_call_id = part.get("callID", "")
                        state = part.get("state", {})
                        status = state.get("status", "")

                        lines.append(f"\n### Tool Call: `{tool_name}` (id: {tool_call_id}, status: {status})")

                        # Input
                        input_data = state.get("input", {})
                        if input_data:
                            lines.append(f"\n**Input:**")
                            lines.append(f"```json\n{json.dumps(input_data, indent=2, ensure_ascii=False)}\n```")

                        # Output
                        output_data = state.get("output", {})
                        if output_data:
                            lines.append(f"\n**Output:**")
                            if isinstance(output_data, str):
                                lines.append(f"{output_data[:5000]}")  # Truncate huge outputs
                            else:
                                lines.append(f"```json\n{json.dumps(output_data, indent=2, ensure_ascii=False)[:5000]}\n```")

                    elif part_type == "step-start":
                        text = part.get("text", "")
                        if text:
                            lines.append(f"\n### Step Start")
                            lines.append(f"{text}")
                    elif part_type == "step-finish":
                        text = part.get("text", "")
                        if text:
                            lines.append(f"\n### Step Finish")
                            lines.append(f"{text}")
                    elif part_type == "reasoning":
                        text = part.get("text", "")
                        if text:
                            lines.append(f"\n### Reasoning")
                            lines.append(f"```thinking\n{text}\n```")
                    else:
                        lines.append(f"\n### Part: `{part_type}`")
                        lines.append(f"```json\n{json.dumps(part, indent=2, ensure_ascii=False)[:2000]}\n```")

            elif role == "system":
                lines.append(f"\n## System")
                for part in parts:
                    if part.get("type") == "text":
                        lines.append(f"\n{part.get('text', '')}")

            else:
                lines.append(f"\n## Message: `{role}` ({msg_id})")
                lines.append(f"```json\n{json.dumps(msg, indent=2, ensure_ascii=False)[:2000]}\n```")

        # Write file
        md_content = "\n".join(lines) + "\n"
        with open(out_file, "w", encoding="utf-8") as f:
            f.write(md_content)

        # Update manifest
        manifest["opencode"][ses_id] = latest_ts
        return True

    except Exception as e:
        print(f"Error exporting OpenCode session {meta_file}: {e}", file=sys.stderr)
        return False


# --- Module display for waybar ---

def display_module():
    """Output JSON for waybar module."""
    try:
        silo_ok = is_silo_mounted()
        target = get_target_dir()

        # Count sessions
        pi_count = 0
        if PI_SESSIONS.exists():
            for cwd_dir in PI_SESSIONS.iterdir():
                if cwd_dir.is_dir():
                    pi_count += len(list(cwd_dir.glob("*.jsonl")))

        oc_count = 0
        oc_session_dir = OC_STORAGE / "session"
        if oc_session_dir.exists():
            for project_dir in oc_session_dir.iterdir():
                if project_dir.is_dir():
                    oc_count += len(list(project_dir.glob("*.json")))

        # Count exported
        manifest = load_manifest(target)
        pi_exported = len(manifest.get("pi", {}))
        oc_exported = len(manifest.get("opencode", {}))
        total_exported = pi_exported + oc_exported

        # Pending
        pi_pending = max(0, pi_count - pi_exported)
        oc_pending = max(0, oc_count - oc_exported)
        total_pending = pi_pending + oc_pending

        # Determine icon
        if total_pending == 0:
            icon = "󰄬"  # checkmark
            tooltip = f"All sessions archived ({total_exported})"
        else:
            icon = "󰏔"  # archive
            tooltip = f"Sessions: {total_pending} pending / {total_exported} archived\nPI: {pi_pending}/{pi_count}\nOC: {oc_pending}/{oc_count}"

        if not silo_ok:
            tooltip += "\n⚠ Silo not mounted → local backup"

        # Last export time
        all_ts = list(manifest.get("pi", {}).values()) + list(manifest.get("opencode", {}).values())
        if all_ts:
            last_ts = max(all_ts)
            last_date = ts_to_iso(last_ts)
            tooltip += f"\nLast: {last_date}"

        print(json.dumps({
            "text": f" {icon} ",
            "tooltip": tooltip,
            "class": "archived" if total_pending == 0 else "pending"
        }))

    except Exception as e:
        print(json.dumps({"text": " 󰏔 ", "tooltip": f"Error: {e}"}))


# --- Main ---

def main():
    if "--module" in sys.argv:
        display_module()
        return

    target = get_target_dir()
    try:
        target.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        print(f"Cannot create target directory {target}: {e}", file=sys.stderr)
        notify("Archive Error", f"Cannot create {target}: {e}", urgency="critical", icon="dialog-error")
        sys.exit(1)

    manifest = load_manifest(target)

    exported_count = 0
    errors = 0

    # Export PI sessions
    if PI_SESSIONS.exists():
        for cwd_dir in sorted(PI_SESSIONS.iterdir()):
            if not cwd_dir.is_dir():
                continue
            for jsonl_file in sorted(cwd_dir.glob("*.jsonl")):
                if export_pi_session(jsonl_file, target, manifest):
                    exported_count += 1
                else:
                    pass  # Skipped or error

    # Export OpenCode sessions
    oc_session_dir = OC_STORAGE / "session"
    if oc_session_dir.exists():
        for project_dir in sorted(oc_session_dir.iterdir()):
            if not project_dir.is_dir():
                continue
            for meta_file in sorted(project_dir.glob("*.json")):
                if export_opencode_session(meta_file, target, manifest):
                    exported_count += 1
                else:
                    pass  # Skipped or error

    # Save manifest
    save_manifest(target, manifest)

    # Notify
    silo_ok = is_silo_mounted()
    if exported_count > 0:
        source = "Silo NAS" if silo_ok else "local backups"
        notify(
            "Sessions Archived",
            f"{exported_count} session(s) → {source}",
            urgency="normal" if silo_ok else "critical",
            icon="drive-harddisk" if silo_ok else "folder"
        )
        print(f"Exported {exported_count} session(s) to {target}")
    else:
        print(f"No new sessions to export (target: {target})")


if __name__ == "__main__":
    main()
