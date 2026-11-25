"""Source-derived behavior inventory used by audit_ups_hotspots_0743.

This is a lexical Lua inventory, not a Lua interpreter, profiler or proof of
runtime installation. Comments/strings and balanced call arguments are parsed
before extracting sites; guards and function definitions are not registrations.
Dynamic dispatch, conditions, wrappers and variable aliases remain explicitly
unresolved. Generated output and reviewed hand-written diagrams have separate
freshness receipts so regeneration cannot silently approve a stale diagram.
"""
from __future__ import annotations

import ast
import hashlib
import json
import pathlib
import re
import subprocess
from collections import Counter, deque
from dataclasses import dataclass
from typing import Callable

SCHEMA = "tech-priests-behavior-source-inventory-v1"
JSON_PATH = "docs/BEHAVIOR_SOURCE_INVENTORY.json"
MD_PATH = "docs/BEHAVIOR_SOURCE_INVENTORY.md"
REVIEW_PATH = "docs/BEHAVIOR_MAP_REVIEW.json"
SOURCE_PATTERNS = ("control.lua", "scripts/**/*.lua", "shared/**/*.lua")
CURATED_MAPS = (
    "BEHAVIOR_FUNCTION_MAP_0659.md",
    "BEHAVIOR_MERMAID_MAP_0660.md",
    "RECOVERY_AUTHORITY_MAP_CURRENT.md",
)
# Reviewed dependency coverage for the hand-written drilldowns. The umbrella
# maps above always include EVERY inventoried runtime file, including additions.
DRILLDOWN_SOURCES = {
    "0661": ("planning_constraints_0646", "logistics_fetch_executor_0527", "scan_routing_0610", "station_catalog", "storage_role_authority_0686", "efficiency_economy_0587", "runtime_tick_broker", "efficiency_economy_0598", "logistics_fetch_executor_0526", "station_area_change_invalidator_0634", "station_work_inventory", "proxy_ammo_hardener_0649", "catalog_dense_scan_1478", "entity_identity_1481", "catalog_owner_index_1496"),
    "0662": ("direct_acquisition_physical_guard_0649", "direct_acquisition_executor_0513", "movement_controller", "void_movement_authority_0630", "platform_movement_authority", "planning_constraints_0646"),
    "0663": ("direct_acquisition_executor_0513", "order_queue_0469", "movement_controller", "single_dispatcher_0510"),
    "0664": ("movement_controller", "authority_corridor_pathing_0574", "void_movement_authority_0630", "runtime_tick_broker"),
    "0665": ("construction_planner", "construction_site_planner", "construction_bootstrap_ghost_planner_0645", "work_reservations", "single_dispatcher_0510", "self_construction_frustration_gate"),
    "0666": ("infrastructure_first_governor_0640", "master_infrastructure_plan_0644", "construction_bootstrap_ghost_planner_0645", "power_setup_1252", "self_construction_frustration_gate", "planning_constraints_0646", "control.lua", "runtime_tick_broker", "efficiency_economy_0598"),
    "0667": ("single_dispatcher_0510", "action_state_arbiter_0488", "logistics_fetch_executor_0527", "order_queue_0469", "combat_roster_orders"),
    "0668": ("action_state_arbiter_0488", "single_dispatcher_0510", "behavior_tree_monitor_0642"),
    "0669": ("order_queue_0469", "consecration_executor_0515", "priest_lifecycle_authority_0499"),
    "0670": ("emergency_production_executor_0514", "crafting_executor", "emergency_facility_doctrine", "storage_role_authority_0686", "inventory_steward"),
    "0671": ("consecration_executor_0515", "work_reservations", "work_queue_authority", "scripts/core/consecration/*.lua", "shared/combat_roster_catalog.lua", "control.lua"),
    "0672": ("repair_executor_0516", "event_driven_work_feeder_0608", "work_queue_authority", "work_reservations", "combat_repair_doctrine_0517"),
    "0675": ("combat_repair_doctrine_0517", "repair_executor_0516", "action_state_arbiter_0488"),
}


@dataclass(frozen=True)
class Token:
    kind: str
    text: str
    line: int
    start: int
    end: int


@dataclass(frozen=True)
class Call:
    name: str
    line: int
    index: int
    args: tuple[tuple[int, int], ...]
    protected: bool = False


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_json(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def lex(text: str) -> list[Token]:
    """Tokenize comments, quoted/long strings and operators without execution."""
    tokens: list[Token] = []
    i, line, size = 0, 1, len(text)
    while i < size:
        start, first_line = i, line
        char = text[i]
        if char.isspace():
            line += char == "\n"
            i += 1
            continue
        comment = text.startswith("--", i)
        if comment:
            i += 2
        long = re.match(r"\[(=*)\[", text[i:]) if text[i:i + 1] == "[" else None
        if long:
            closer = "]" + long.group(1) + "]"
            end = text.find(closer, i + len(long.group()))
            i = size if end < 0 else end + len(closer)
            if not comment:
                tokens.append(Token("string", text[start:i], first_line, start, i))
        elif comment:
            end = text.find("\n", i)
            i = size if end < 0 else end
        elif char in "\"'":
            i += 1
            while i < size:
                if text[i] == "\\":
                    i += 2
                elif text[i] == char:
                    i += 1
                    break
                else:
                    i += 1
            tokens.append(Token("string", text[start:i], first_line, start, i))
        elif char.isalpha() or char == "_":
            i += 1
            while i < size and (text[i].isalnum() or text[i] == "_"):
                i += 1
            tokens.append(Token("name", text[start:i], first_line, start, i))
        elif char.isdigit() or (char == "." and text[i + 1:i + 2].isdigit()):
            match = re.match(r"(?:0[xX][0-9a-fA-F]+(?:\.[0-9a-fA-F]*)?(?:[pP][+-]?\d+)?|(?:\d+(?:\.(?!\.)\d*)?|\.\d+)(?:[eE][+-]?\d+)?)", text[i:])
            i += len(match.group()) if match else 1
            tokens.append(Token("number", text[start:i], first_line, start, i))
        else:
            op = next((op for op in ("...", "==", "~=", "<=", ">=", "..", "//", "<<", ">>", "::") if text.startswith(op, i)), char)
            i += len(op)
            tokens.append(Token("symbol", op, first_line, start, i))
        line += text[start:i].count("\n")
    return tokens


def string_value(token: Token) -> str:
    raw = token.text
    long = re.match(r"\[(=*)\[", raw)
    if long:
        value = raw[len(long.group()):-(len(long.group()))]
        return value[1:] if value.startswith("\n") else value
    value = raw[1:-1]
    escapes = {"n": "\n", "r": "\r", "t": "\t", "\\": "\\", '"': '"', "'": "'"}
    return re.sub(r"\\(.)", lambda m: escapes.get(m.group(1), "\\" + m.group(1)), value)


def expression(tokens: list[Token], span: tuple[int, int], limit: int = 240) -> str:
    a, b = span
    value = " ".join(token.text for token in tokens[a:b])
    return value if len(value) <= limit else value[:limit] + " …"


def brackets(tokens: list[Token]) -> dict[int, int]:
    stack: list[int] = []
    pairs: dict[int, int] = {}
    for i, token in enumerate(tokens):
        if token.kind == "string":
            continue
        if token.text in ("(", "{", "["):
            stack.append(i)
        elif token.text in (")", "}", "]") and stack:
            left = stack.pop()
            if (tokens[left].text, token.text) not in (("(", ")"), ("{", "}"), ("[", "]")):
                raise ValueError(f"unbalanced delimiter at line {token.line}")
            pairs[left] = i
    if stack:
        raise ValueError(f"unclosed delimiter at line {tokens[stack[-1]].line}")
    return pairs


def split_values(tokens: list[Token], a: int, b: int, pairs: dict[int, int]) -> list[tuple[int, int]]:
    values: list[tuple[int, int]] = []
    start, i, blocks = a, a, 0
    while i < b:
        token = tokens[i]
        if i in pairs:
            i = pairs[i] + 1
            continue
        if token.kind != "string":
            if token.text in ("function", "if", "do", "repeat"):
                blocks += 1
            elif token.text in ("end", "until"):
                blocks = max(0, blocks - 1)
            elif token.text in (",", ";") and blocks == 0:
                if start < i:
                    values.append((start, i))
                start = i + 1
        i += 1
    if start < b:
        values.append((start, b))
    return values


def chain(tokens: list[Token], i: int) -> tuple[str, int]:
    if i >= len(tokens) or tokens[i].kind != "name":
        return "", i
    names = [tokens[i].text]
    j = i + 1
    while j + 1 < len(tokens) and tokens[j].text in (".", ":") and tokens[j + 1].kind == "name":
        names.extend((tokens[j].text, tokens[j + 1].text))
        j += 2
    return "".join(names), j


def calls(tokens: list[Token], pairs: dict[int, int]) -> list[Call]:
    result: list[Call] = []
    for i, token in enumerate(tokens):
        if token.kind != "name" or token.text in ("if", "while", "for", "function", "return", "local"):
            continue
        if i and tokens[i - 1].text in (".", ":", "function"):
            continue
        name, j = chain(tokens, i)
        if j >= len(tokens):
            continue
        next_token = tokens[j]
        if next_token.text == "(" and j in pairs:
            args = tuple(split_values(tokens, j + 1, pairs[j], pairs))
        elif next_token.text == "{" and j in pairs:
            args = ((j, pairs[j] + 1),)
        elif next_token.kind == "string":
            args = ((j, j + 1),)
        else:
            continue
        result.append(Call(name, token.line, i, args))
        if name == "pcall" and args:
            a, b = args[0]
            protected, end = chain(tokens, a)
            if protected and end == b:
                result.append(Call(protected, token.line, i, args[1:], True))
    return result


def table_fields(tokens: list[Token], span: tuple[int, int], pairs: dict[int, int]) -> dict[str, tuple[int, int]]:
    a, b = span
    if a >= b or tokens[a].text != "{" or pairs.get(a) != b - 1:
        return {}
    fields: dict[str, tuple[int, int]] = {}
    for left, right in split_values(tokens, a + 1, b - 1, pairs):
        if left + 2 < right and tokens[left].kind == "name" and tokens[left + 1].text == "=":
            fields[tokens[left].text] = (left + 2, right)
        elif left + 4 < right and tokens[left].text == "[" and tokens[left + 1].kind == "string" and tokens[left + 2].text == "]" and tokens[left + 3].text == "=":
            fields[string_value(tokens[left + 1])] = (left + 4, right)
    return fields


def numeric(text: str) -> int | float | None:
    """Evaluate only finite literal arithmetic, never arbitrary Lua/Python."""
    try:
        node = ast.parse(text, mode="eval").body
        def walk(node):
            if isinstance(node, ast.Constant) and type(node.value) in (int, float):
                return node.value
            if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd)):
                return -walk(node.operand) if isinstance(node.op, ast.USub) else walk(node.operand)
            if isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Sub, ast.Mult, ast.Div, ast.FloorDiv)):
                x, y = walk(node.left), walk(node.right)
                if isinstance(node.op, ast.Add): return x + y
                if isinstance(node.op, ast.Sub): return x - y
                if isinstance(node.op, ast.Mult): return x * y
                if isinstance(node.op, ast.Div): return x / y
                return x // y
            raise ValueError("not literal arithmetic")
        value = walk(node)
        return value if abs(value) < 1e15 else None
    except (SyntaxError, ValueError, TypeError, ZeroDivisionError, OverflowError):
        return None


def literal_value(tokens: list[Token], span: tuple[int, int]):
    a, b = span
    if b - a == 1:
        token = tokens[a]
        if token.kind == "string": return string_value(token)
        if token.text == "true": return True
        if token.text == "false": return False
    return numeric(expression(tokens, span))


def declared_scalars(tokens: list[Token], pairs: dict[int, int]) -> dict[str, list[dict]]:
    result: dict[str, list[dict]] = {}
    for i, token in enumerate(tokens):
        if token.kind != "name" or (i and tokens[i - 1].text in (".", ":")):
            continue
        name, j = chain(tokens, i)
        if j + 1 >= len(tokens) or tokens[j].text != "=":
            continue
        a = j + 1
        if tokens[a].text == "{" and a in pairs:
            entries = [(name + "." + key, span) for key, span in table_fields(tokens, (a, pairs[a] + 1), pairs).items()]
        else:
            end = a + 1
            while end + 1 < len(tokens) and tokens[end].text in ("+", "-", "*", "/", "//") and tokens[end + 1].kind == "number":
                end += 2
            entries = [(name, (a, end))]
        for key, span in entries:
            value = literal_value(tokens, span)
            if value is not None:
                result.setdefault(key, []).append({"line": tokens[span[0]].line, "value": value})
    return result


def describe(tokens: list[Token], span: tuple[int, int], scalars: dict) -> dict:
    text = expression(tokens, span)
    result = {"expression": text}
    value = literal_value(tokens, span)
    if value is not None:
        result["literal"] = value
    else:
        key = text.replace(" ", "")
        values = scalars.get(key, [])
        if values:
            result["declared_scalar_candidates"] = values
        result["runtime_value"] = "not evaluated"
    return result


def function_sites(tokens: list[Token], pairs: dict[int, int]) -> list[dict]:
    result = []
    for i, token in enumerate(tokens):
        if token.kind != "name" or token.text != "function":
            continue
        name, j = chain(tokens, i + 1)
        kind = "declaration"
        if not name:
            kind = "anonymous"
            if i >= 2 and tokens[i - 1].text == "=":
                start = i - 2
                while start >= 2 and tokens[start - 1].text in (".", ":") and tokens[start - 2].kind == "name":
                    start -= 2
                name = "".join(t.text for t in tokens[start:i - 1])
                kind = "assigned-function"
        parameters = expression(tokens, (j + 1, pairs[j])) if j in pairs and tokens[j].text == "(" else "<unresolved>"
        result.append({"line": token.line, "name": name or "<anonymous>", "kind": kind, "parameters": parameters,
                       "local": i > 0 and tokens[i - 1].text == "local"})
    return result


def inventory_module(path: pathlib.Path, root: pathlib.Path, scan_risk: Callable[[str], str]) -> dict:
    raw = path.read_bytes()
    source = raw.decode("utf-8")
    tokens = lex(source)
    pairs = brackets(tokens)
    sites = calls(tokens, pairs)
    scalars = declared_scalars(tokens, pairs)
    rel = path.relative_to(root).as_posix()
    result = {"path": rel, "module": rel[:-4].replace("/", "."), "sha256": digest(raw),
              "lines": len(source.splitlines()), "functions": function_sites(tokens, pairs),
              "dependencies": [], "module_string_references": [], "module_tables": [], "install_calls": [],
              "broker_services": [], "event_routes": [], "scans": [], "state_writers": [],
              "wrapper_candidates": [], "storage_roots": [], "commands": [], "unresolved_loads": []}
    aliases: dict[str, set[str]] = {}
    for call in sites:
        base = {"line": call.line, "callee": call.name, "protected_call": call.protected}
        method = re.split(r"[.:]", call.name)[-1]
        if call.name == "require":
            arg = call.args[0] if call.args else (0, 0)
            a, b = arg
            if b - a == 1 and tokens[a].kind == "string":
                target = string_value(tokens[a])
                result["dependencies"].append({**base, "target": target, "kind": "literal-require", "execution": "conditional-or-unconditional; not evaluated"})
                # A unique lexical local assignment is useful, but never proof
                # against reassignment, scope shadowing or wrapper replacement.
                if call.index >= 2 and tokens[call.index - 1].text == "=":
                    alias = tokens[call.index - 2].text
                    aliases.setdefault(alias, set()).add(target)
            else:
                result["unresolved_loads"].append({**base, "argument": expression(tokens, arg)})
        if (method == "install" or method.startswith("install_")) and "." in call.name:
            result["install_calls"].append(base)
        if method == "register_service" and ("." in call.name or ":" in call.name):
            fields = table_fields(tokens, call.args[0], pairs) if call.args else {}
            result["broker_services"].append({**base, "fields": {key: describe(tokens, value, scalars) for key, value in fields.items()},
                                               "specification": "literal-table" if fields else "dynamic-unresolved",
                                               "installation": "source-call-site-only"})
        if method in ("on_event", "on_nth_tick", "on_init", "on_load", "on_configuration_changed"):
            is_timer = method == "on_nth_tick"
            offset = 3 if method == "on_event" else 2 if is_timer else 1
            opts = table_fields(tokens, call.args[offset], pairs) if len(call.args) > offset else {}
            selector = call.args[0] if call.args and method in ("on_event", "on_nth_tick") else None
            handler = call.args[1 if selector else 0] if len(call.args) > (1 if selector else 0) else None
            result["event_routes"].append({**base, "kind": "direct-script" if call.name.startswith("script.") else "registry-or-helper",
                                           "event": method, "selector": describe(tokens, selector, scalars) if selector else {},
                                           "handler": expression(tokens, handler) if handler else "<missing>",
                                           "options": {key: describe(tokens, value, scalars) for key, value in opts.items()},
                                           "action": "clear" if handler and expression(tokens, handler) == "nil" else "register-or-forward"})
        if method in ("find_entities_filtered", "find_entities", "count_entities_filtered", "find_non_colliding_position"):
            arg = call.args[0] if call.args else (0, 0)
            snippet = expression(tokens, arg)
            result["scans"].append({**base, "arguments": [expression(tokens, span) for span in call.args],
                                     "static_risk_hint": scan_risk(call.name + "(" + snippet + ")"),
                                     "runtime_cost": "unmeasured"})
        if method in ("add_command", "add_interface"):
            result["commands"].append({**base, "arguments": [expression(tokens, span) for span in call.args]})
        if method in ("set_command", "create_entity", "destroy", "insert", "remove", "set_stack", "transfer_stack") or call.name == "tech_priests_request_movement_0418":
            result["state_writers"].append({**base, "kind": "mutation-call-candidate"})
    for record in result["install_calls"]:
        owner = re.split(r"[.:]", record["callee"])[0]
        candidates = sorted(aliases.get(owner, set()))
        record["literal_alias_candidates"] = candidates
        record["resolution"] = "lexical-alias-only" if candidates else "dynamic-or-global-unresolved"
    writer_names = re.compile(r"^(?:pair(?:\.|$)|storage(?:\.|$)|global(?:\.|$)|_G(?:\.|$))|(?:movement_request|active_order|active_leaf_task|canonical_action|direct_acquisition_task|logistics_fetch|emergency_craft)")
    for i, token in enumerate(tokens):
        if token.kind == "string":
            value = string_value(token)
            if re.fullmatch(r"(?:scripts|shared)\.[A-Za-z0-9_.-]+", value):
                result["module_string_references"].append({"line": token.line, "target": value, "resolution": "reference-only; may be retired, diagnostic or a dynamic dispatch target"})
        if token.kind != "name" or (i and tokens[i - 1].text in (".", ":")):
            continue
        name, j = chain(tokens, i)
        if j < len(tokens) and tokens[j].text == "[" and j in pairs:
            close = pairs[j]
            name += "[" + expression(tokens, (j + 1, close), 100) + "]"
            j = close + 1
            while j + 1 < len(tokens) and tokens[j].text == "." and tokens[j + 1].kind == "name":
                name += "." + tokens[j + 1].text
                j += 2
        if j + 1 < len(tokens) and tokens[j].text == "=":
            if tokens[j + 1].text == "{" and j + 1 in pairs:
                start, end = j + 1, pairs[j + 1]
                module_refs = [{"line": item.line, "target": string_value(item)} for item in tokens[start + 1:end]
                               if item.kind == "string" and re.fullmatch(r"(?:scripts|shared)\.[A-Za-z0-9_.-]+", string_value(item))]
                if module_refs:
                    role = "ordered-installer-specification" if name == "HARDENERS" else "explicit-retirement-table" if name == "RETIRED" else "module-reference-table; dispatch not evaluated"
                    record = {"line": token.line, "name": name, "role": role, "references_in_source_order": module_refs}
                    if name == "RETIRED":
                        record["retirement_reasons"] = {key: literal_value(tokens, value) for key, value in table_fields(tokens, (start, end + 1), pairs).items()}
                    result["module_tables"].append(record)
            if writer_names.search(name):
                result["state_writers"].append({"line": token.line, "target": name, "kind": "state-assignment"})
            if tokens[j + 1].text == "function" and ("." in name or "[" in name):
                result["wrapper_candidates"].append({"line": token.line, "target": name, "kind": "function-replacement-candidate; original/wrapper semantics not inferred"})
            if name.startswith(("previous", "old_", "original", "prior_")):
                result["wrapper_candidates"].append({"line": token.line, "target": name, "kind": "saved-function-or-value-candidate", "value": expression(tokens, (j + 1, min(len(tokens), j + 5)), 100)})
        if name.startswith(("storage.", "global.")):
            result["storage_roots"].append({"line": token.line, "expression": name})
    for key in ("state_writers", "wrapper_candidates", "storage_roots"):
        unique = {json.dumps(row, sort_keys=True): row for row in result[key]}
        result[key] = sorted(unique.values(), key=lambda row: (row["line"], json.dumps(row, sort_keys=True)))
    return result


def runtime_files(source: pathlib.Path) -> list[pathlib.Path]:
    paths = {path for pattern in SOURCE_PATTERNS for path in source.glob(pattern) if path.is_file()}
    if source / "control.lua" not in paths:
        raise ValueError("runtime source is incomplete: control.lua missing")
    if not any(path.relative_to(source).parts[0] == "scripts" for path in paths):
        raise ValueError("runtime source is incomplete: scripts/ missing")
    repo = source.parent
    if (repo / ".git").exists():
        tracked = subprocess.run(["git", "ls-files", "-t", "-z", "--", source.name + "/control.lua", source.name + "/scripts", source.name + "/shared"],
                                 cwd=repo, check=True, text=True, capture_output=True).stdout
        omitted = [row[2:] for row in tracked.split("\0") if row.startswith("S ") and row.endswith(".lua") and not (repo / row[2:]).is_file()]
        if omitted:
            raise ValueError("runtime source is sparse/incomplete; materialize: " + ", ".join(omitted[:12]))
    return sorted(paths)


def build_inventory(source: pathlib.Path, scan_risk: Callable[[str], str]) -> dict:
    modules = [inventory_module(path, source, scan_risk) for path in runtime_files(source)]
    by_name = {module["module"]: module for module in modules}
    edges = {name: {item["target"] for item in module["dependencies"] if item["target"] in by_name} for name, module in by_name.items()}
    seen, pending = set(), deque(["control"])
    while pending:
        name = pending.popleft()
        if name in seen: continue
        seen.add(name)
        pending.extend(sorted(edges.get(name, set()) - seen))
    for module in modules:
        module["reachability"] = "runtime-entrypoint" if module["module"] == "control" else "potential-literal-require-path" if module["module"] in seen else "not-resolved-from-literal-requires"
        for dep in module["dependencies"]:
            dep["target_scope"] = "inventoried-runtime-module" if dep["target"] in by_name else "external-or-outside-inventory"
    source_digest = digest("\n".join(module["path"] + "\0" + module["sha256"] for module in modules).encode())
    keys = ("functions", "dependencies", "module_string_references", "module_tables", "install_calls", "broker_services", "event_routes", "scans", "state_writers", "wrapper_candidates", "storage_roots", "commands", "unresolved_loads")
    counts = {key: sum(len(module[key]) for module in modules) for key in keys}
    counts.update(modules=len(modules), named_functions=sum(sum(fn["name"] != "<anonymous>" for fn in module["functions"]) for module in modules),
                  potential_literal_reachable_modules=len(seen))
    return {"schema": SCHEMA, "source_scope": list(SOURCE_PATTERNS), "source_digest": source_digest,
            "generator_sha256": digest(pathlib.Path(__file__).read_bytes()),
            "evidence_class": "static lexical inventory; no runtime or performance acceptance",
            "limitations": ["Literal require reachability includes calls in unexecuted branches/functions; it is potential, not installed.",
                            "Dynamic require, globals, aliases, generated loops and function wrappers cannot be fully resolved lexically.",
                            "Module string references include retired modules and lookup tables; they are not load edges.",
                            "Named/anonymous functions are source declarations, not an exact interprocedural call graph.",
                            "Scalar candidates are declarations in the same file, not evaluated runtime settings.",
                            "State-writer/wrapper/scan records are review candidates; alias-mediated effects can be missed.",
                            "No source count, diagram freshness result or missing profiler sample proves runtime speed."],
            "counts": counts, "modules": modules}


def fmt(value: dict | None) -> str:
    if not value: return "—"
    if "literal" in value: return str(value["literal"])
    text = value.get("expression", "?")
    candidates = value.get("declared_scalar_candidates", [])
    if candidates:
        text += " (declared: " + ", ".join(str(item["value"]) for item in candidates) + ")"
    return text


def cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def table(headers: list[str], rows: list[list[object]]) -> list[str]:
    return ["| " + " | ".join(headers) + " |", "| " + " | ".join("---" for _ in headers) + " |"] + ["| " + " | ".join(cell(item) for item in row) + " |" for row in rows]


def markdown(report: dict) -> str:
    counts, modules = report["counts"], report["modules"]
    lines = ["# Behavior Source Inventory", "", "Generated by `python3 tools/audit_ups_hotspots_0743.py --write-behavior-maps`.", "",
             "**Evidence: static source inventory. Runtime installation, behavior completion and native UPS are not established here.**", "",
             f"Source content digest: `{report['source_digest']}`. Generator digest: `{report['generator_sha256']}`.", "",
             "The complete machine-readable [inventory](BEHAVIOR_SOURCE_INVENTORY.json) contains every inventoried module's content hash, named and anonymous functions, dependency/install call sites, service specifications, event routes, scan sites, state-writer candidates and unresolved loads.", "",
             "## Coverage", ""]
    lines += table(["Source records", "Count"], [[key.replace("_", " "), value] for key, value in counts.items()])
    lines += ["", "Scope: `control.lua`, all Lua files under `scripts/` and `shared/`. Prototype/data-stage code, migrations, tests and archives are outside this runtime behavior inventory.", "",
              "A service row is an actual lexical call site, including `pcall` and table-call syntax. Type guards, comments, strings and function declarations do not create rows. A row may be conditional, disabled or forwarded; do not sum rows as concurrently installed handlers.", "",
              "## Runtime Entry Points", "", "Literal requirements in `control.lua`, in source order. Calls protected by `pcall` remain conditional.", ""]
    control = next(module for module in modules if module["module"] == "control")
    lines += table(["Line", "Module", "Protected"], [[row["line"], row["target"], row["protected_call"]] for row in control["dependencies"]])
    lines += ["", "## Installer and Retirement Tables", "", "Explicit `HARDENERS` and `RETIRED` source tables are distinguished from other module reference tables in JSON. A declared installer is not a successful installation receipt.", ""]
    rows = []
    for module in modules:
        for module_table in module["module_tables"]:
            if module_table["name"] not in ("HARDENERS", "RETIRED"):
                continue
            for order, item in enumerate(module_table["references_in_source_order"], 1):
                reason = module_table.get("retirement_reasons", {}).get(item["target"], "")
                rows.append([module_table["name"], order, item["target"], reason, f"{module['path']}:{item['line']}"])
    lines += table(["Table", "Source order", "Module", "Retirement reason", "Source"], rows)
    lines += ["", "## Broker Services", "", "Cadence, budget and priority are source expressions. Parenthetical values are same-file scalar declarations, not executed settings. Inline callbacks and all other fields remain in JSON.", ""]
    rows = []
    for module in modules:
        for service in module["broker_services"]:
            fields = service["fields"]
            rows.append([fmt(fields.get("name")), fmt(fields.get("category")), fmt(fields.get("interval")), fmt(fields.get("budget")), fmt(fields.get("priority")), f"{module['path']}:{service['line']}"])
    lines += table(["Service", "Category", "Interval (ticks)", "Budget", "Priority", "Source"], rows)
    lines += ["", "## Event and Timer Routes", "", "Registry helper calls and forwarding/clear operations are retained. Owner metadata is shown only when present in a literal options table. Dynamic options remain unresolved in JSON.", ""]
    rows = []
    for module in modules:
        for route in module["event_routes"]:
            opts = route["options"]
            rows.append([route["event"], fmt(route["selector"]), fmt(opts.get("owner")), fmt(opts.get("route")), route["action"], f"{module['path']}:{route['line']}"])
    lines += table(["API", "Event / interval", "Owner", "Route", "Operation", "Source"], rows)
    lines += ["", "## Module Index", "", "`potential-literal-require-path` means a source path of literal require calls exists from control; the calls may sit inside functions or branches which never execute. `not-resolved` also includes dynamic loaders and retired source: it does not mean dead code.", ""]
    rows = []
    for module in modules:
        link = f"[{module['path']}](../tech-priests_src/{module['path']})"
        rows.append([link, len(module["functions"]), len(module["broker_services"]), len(module["event_routes"]), len(module["scans"]), len(module["state_writers"]), module["reachability"]])
    lines += table(["Module", "Functions", "Services", "Event routes", "Scans", "Writer candidates", "Reachability"], rows)
    lines += ["", "## Unresolved and Conditional Edges", ""]
    for limitation in report["limitations"]:
        lines.append("- " + limitation)
    rows = [[module["path"], load["line"], load["argument"]] for module in modules for load in module["unresolved_loads"]]
    lines += [""] + table(["Module", "Line", "Dynamic require argument"], rows)
    lines += ["", "## Keeping Maps Current", "",
              "1. Update source and the affected curated Mermaid/function maps together.",
              "2. Run `python3 tools/audit_ups_hotspots_0743.py --write-behavior-maps` to regenerate this inventory.",
              "3. Review the changed source against the curated diagrams, then explicitly run `python3 tools/audit_ups_hotspots_0743.py --acknowledge-behavior-map-review`.",
              "4. Run `python3 tools/audit_ups_hotspots_0743.py --check-behavior-maps`. Generated freshness and curated review fingerprints must both match.", "",
              "Regeneration does not acknowledge manual diagram review. The separate review receipt records document and relevant source hashes; it is an accountable review checkpoint, not semantic proof or runtime acceptance.", ""]
    return "\n".join(lines)


def curated_paths(repo: pathlib.Path) -> list[pathlib.Path]:
    docs = repo / "docs"
    drilldowns = list(docs.glob("BEHAVIOR_MERMAID_FUNCTION_DRILLDOWN_*.md"))
    found = Counter(re.search(r"DRILLDOWN_(\d+)", path.name).group(1) for path in drilldowns)
    missing = set(DRILLDOWN_SOURCES) - set(found)
    duplicates = [key for key, count in found.items() if count != 1]
    if missing or duplicates:
        raise ValueError(f"curated drilldown set incomplete/ambiguous: missing={sorted(missing)} duplicates={duplicates}")
    return sorted({*(docs / name for name in CURATED_MAPS), *drilldowns})


def review_receipt(repo: pathlib.Path, report: dict) -> dict:
    modules = report["modules"]
    maps = []
    for path in curated_paths(repo):
        match = re.match(r"BEHAVIOR_MERMAID_FUNCTION_DRILLDOWN_(\d+)", path.name)
        if match:
            if match.group(1) not in DRILLDOWN_SOURCES:
                raise ValueError(f"new curated drilldown requires explicit dependency coverage: {path.name}")
            patterns = [name if name.endswith(".lua") else "scripts/core/" + name + ".lua" for name in DRILLDOWN_SOURCES[match.group(1)]]
            selected = []
            for pattern in patterns:
                hits = [module for module in modules if pathlib.PurePosixPath(module["path"]).match(pattern)]
                if not hits:
                    raise ValueError(f"curated source dependency missing: {path.name}: {pattern}")
                selected.extend(hits)
            covered = {module["path"]: module["sha256"] for module in selected}
            reviewed_digest = digest("\n".join(name + "\0" + sha for name, sha in sorted(covered.items())).encode())
        else:
            patterns = list(SOURCE_PATTERNS)
            covered = {module["path"]: module["sha256"] for module in modules}
            reviewed_digest = report["source_digest"]
        maps.append({"path": path.relative_to(repo).as_posix(), "sha256": digest(path.read_bytes()),
                     "source_patterns": patterns, "covered_source_files": len(covered), "reviewed_source_digest": reviewed_digest})
    return {"schema": "tech-priests-behavior-map-review-v1",
            "review_meaning": "Explicit source/diagram review acknowledgment; no semantic or runtime proof.",
            "source_digest": report["source_digest"],
            "source_scope": report["source_scope"],
            "maps": maps}


def run(repo: pathlib.Path, source: pathlib.Path, scan_risk: Callable[[str], str], *, write: bool = False, check: bool = False, acknowledge: bool = False) -> int:
    report = build_inventory(source, scan_risk)
    expected = {JSON_PATH: canonical_json(report), MD_PATH: markdown(report)}
    if write:
        for relative, content in expected.items():
            target = repo / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8")
        print(f"[behavior-map] generated {report['counts']['modules']} modules, {report['counts']['functions']} function sites, {report['counts']['broker_services']} broker call sites; static inventory only")
    if acknowledge:
        receipt = review_receipt(repo, report)
        (repo / REVIEW_PATH).write_text(canonical_json(receipt), encoding="utf-8")
        print(f"[behavior-map] recorded explicit review acknowledgment for {len(receipt['maps'])} curated maps; no runtime acceptance")
    if check:
        errors = []
        for relative, content in expected.items():
            path = repo / relative
            if not path.is_file():
                errors.append(f"missing generated artifact: {relative}")
            elif path.read_text(encoding="utf-8") != content:
                errors.append(f"stale generated artifact: {relative}; regenerate after reviewing source changes")
        receipt_path = repo / REVIEW_PATH
        try:
            actual = json.loads(receipt_path.read_text(encoding="utf-8"))
            receipt = review_receipt(repo, report)
            if actual != receipt:
                old = {row['path']: row for row in actual.get('maps', [])}
                for row in receipt["maps"]:
                    if old.get(row["path"]) != row:
                        errors.append(f"curated source/diagram review stale: {row['path']}")
                removed = set(old) - {row["path"] for row in receipt["maps"]}
                errors.extend(f"reviewed map removed: {path}" for path in sorted(removed))
                if not errors:
                    errors.append("curated review schema/scope changed")
        except (OSError, ValueError, KeyError) as exc:
            errors.append(f"curated review receipt missing/invalid: {exc}")
        if errors:
            for error in errors:
                print("[behavior-map] FAIL " + error)
            return 1
        print(f"[behavior-map] PASS generated coverage and {len(receipt['maps'])} curated review fingerprints current; source digest={report['source_digest']}; runtime unverified")
    return 0
