#!/usr/bin/env node
/**
 * test_bar_config_schema.js
 * Opaque-box test suite for Bar configuration schema and validator.
 * Validates config/defaults/bar.js and config/ConfigValidator.js.
 */

const fs = require("fs");
const path = require("path");
const vm = require("vm");
const assert = require("assert");

// Helper to evaluate QML library JS files in Node.js
function loadQmlJs(relPath) {
    const absPath = path.resolve(__dirname, "../../", relPath);
    if (!fs.existsSync(absPath)) {
        throw new Error(`Target file not found: ${absPath}`);
    }
    const code = fs.readFileSync(absPath, "utf8").replace(/\.pragma\s+library;?/g, "");
    const sandbox = {};
    vm.createContext(sandbox);
    vm.runInContext(code, sandbox);
    return sandbox;
}

let passed = 0;
let failed = 0;
const results = [];

function test(name, fn) {
    try {
        fn();
        passed++;
        results.push({ name, status: "PASS" });
        console.log(`  ✓ ${name}`);
    } catch (err) {
        failed++;
        results.push({ name, status: "FAIL", error: err.message });
        console.error(`  ✗ ${name}: ${err.message}`);
    }
}

console.log("=== Running Config Schema & Validator Tests ===");

const barDefaults = loadQmlJs("config/defaults/bar.js");
const validator = loadQmlJs("config/ConfigValidator.js");

// Group 1: Default Data Schema
test("F1-SCHEMA-1: config/defaults/bar.js exports a valid data object", () => {
    assert(barDefaults.data, "barDefaults.data must exist");
    assert.strictEqual(typeof barDefaults.data, "object", "barDefaults.data must be an object");
});

test("F1-SCHEMA-2: bar.data contains 'style' with default value 'default'", () => {
    assert("style" in barDefaults.data, "barDefaults.data must contain 'style' key");
    assert.strictEqual(barDefaults.data.style, "default", "Default style must be 'default'");
});

test("F1-SCHEMA-3: bar.data contains standard bar keys alongside 'style'", () => {
    assert.strictEqual(barDefaults.data.position, "top", "Default position must be 'top'");
    assert(Array.isArray(barDefaults.data.screenList), "screenList must be an Array");
    assert.strictEqual(barDefaults.data.screenList.length, 0, "screenList default must be empty array");
    assert.strictEqual(typeof barDefaults.data.enableFirefoxPlayer, "boolean");
    assert.strictEqual(typeof barDefaults.data.use12hFormat, "boolean");
});

// Group 2: Validator Style Key Validation
test("F1-VALIDATOR-1: Validator accepts 'default' as a valid style", () => {
    const validated = validator.validate("default", "default", "style");
    assert.strictEqual(validated, "default");
});

test("F1-VALIDATOR-2: Validator accepts 'island' as a valid style", () => {
    const validated = validator.validate("island", "default", "style");
    assert.strictEqual(validated, "island");
});

test("F1-VALIDATOR-3: Validator rejects invalid style strings and falls back to default", () => {
    const invalidValues = ["dock", "floating", "dynamic-island", "topbar", "", "ISLAND", "Default"];
    for (const val of invalidValues) {
        const validated = validator.validate(val, "default", "style");
        assert.strictEqual(validated, "default", `Value '${val}' should fallback to 'default'`);
    }
});

test("F1-VALIDATOR-4: Validator rejects non-string types for style and falls back to default", () => {
    const invalidTypes = [null, undefined, 123, true, false, {}, [], () => {}];
    for (const val of invalidTypes) {
        const validated = validator.validate(val, "default", "style");
        assert.strictEqual(validated, "default", `Type '${typeof val}' should fallback to 'default'`);
    }
});

// Group 3: Full Object Validation
test("F1-FULLOBJ-1: Valid full bar config preserves 'island' style", () => {
    const input = {
        position: "top",
        style: "island",
        screenList: ["DP-1"],
        enableFirefoxPlayer: true,
        use12hFormat: true
    };
    const validated = validator.validate(input, barDefaults.data, "bar");
    assert.strictEqual(validated.style, "island");
    assert.strictEqual(validated.position, "top");
    assert.deepStrictEqual(validated.screenList, ["DP-1"]);
    assert.strictEqual(validated.enableFirefoxPlayer, true);
    assert.strictEqual(validated.use12hFormat, true);
});

test("F1-FULLOBJ-2: Missing 'style' key in user config is populated with default 'default'", () => {
    const input = {
        position: "top",
        screenList: ["HDMI-1"],
        enableFirefoxPlayer: false,
        use12hFormat: false
    };
    const validated = validator.validate(input, barDefaults.data, "bar");
    assert.strictEqual(validated.style, "default");
    assert.deepStrictEqual(validated.screenList, ["HDMI-1"]);
});

test("F1-FULLOBJ-3: Invalid 'style' in user config is corrected while preserving other valid keys", () => {
    const input = {
        position: "top",
        style: "corrupted_style_entry",
        screenList: ["eDP-1"],
        enableFirefoxPlayer: true,
        use12hFormat: false
    };
    const validated = validator.validate(input, barDefaults.data, "bar");
    assert.strictEqual(validated.style, "default");
    assert.deepStrictEqual(validated.screenList, ["eDP-1"]);
    assert.strictEqual(validated.enableFirefoxPlayer, true);
});

test("F1-FULLOBJ-4: Null or non-object input cleanly resets to bar defaults", () => {
    const validatedNull = validator.validate(null, barDefaults.data, "bar");
    assert.deepStrictEqual(JSON.parse(JSON.stringify(validatedNull)), JSON.parse(JSON.stringify(barDefaults.data)));

    const validatedString = validator.validate("not an object", barDefaults.data, "bar");
    assert.deepStrictEqual(JSON.parse(JSON.stringify(validatedString)), JSON.parse(JSON.stringify(barDefaults.data)));
});

// Group 4: Preset Integrity
test("F1-PRESET-1: Nonchalant Default preset bar.json validates cleanly", () => {
    const presetPath = path.resolve(__dirname, "../../assets/presets/Nonchalant Default/bar.json");
    assert(fs.existsSync(presetPath), "Preset file must exist");
    const content = fs.readFileSync(presetPath, "utf8");
    const parsed = JSON.parse(content);
    const validated = validator.validate(parsed, barDefaults.data, "bar");
    assert.strictEqual(validated.style, "default");
    assert.strictEqual(validated.position, "top");
});

console.log(`\nSchema Tests Summary: ${passed} passed, ${failed} failed.`);
if (failed > 0) {
    process.exit(1);
}
