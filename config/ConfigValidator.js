.pragma library

function clone(obj) {
    return JSON.parse(JSON.stringify(obj));
}

function validate(current, defaults, keyName) {
    if (current === undefined || current === null) {
        return clone(defaults);
    }

    if (Array.isArray(defaults)) {
        if (!Array.isArray(current)) {
            return clone(defaults);
        }
        return current;
    }

    if (typeof defaults === 'object') {
        if (typeof current !== 'object' || Array.isArray(current)) {
            return clone(defaults);
        }

        const result = {};
        for (const key in defaults) {
            result[key] = validate(current[key], defaults[key], key);
        }
        // Repair the old hover pair while preserving custom foregrounds and backgrounds.
        if (keyName === "srPrimaryFocus"
                && result.itemColor === "overPrimary"
                && result.gradientType === "linear"
                && result.gradient.length === 1
                && result.gradient[0]?.[0] === "overPrimaryContainer") {
            result.itemColor = defaults.itemColor;
        }
        return result;
    }

    if (typeof current !== typeof defaults) {
        return defaults;
    }

    if (keyName === "gradientType") {
        const validTypes = ["linear", "radial", "halftone"];
        if (validTypes.indexOf(current) === -1) {
            return defaults;
        }
    }

    if (keyName === "position") {
        const validPositions = ["top", "bottom"];
        if (validPositions.indexOf(current) === -1) {
            return defaults;
        }
    }

    if (keyName === "style") {
        const validStyles = ["default", "island", "pills", "left"];
        if (validStyles.indexOf(current) === -1) {
            return defaults;
        }
    }

    if (keyName === "sidebarPosition") {
        const validSidebarPositions = ["left", "right"];
        if (validSidebarPositions.indexOf(current) === -1) {
            return defaults;
        }
    }

    if (keyName === "unit") {
        const validUnits = ["C", "F"];
        if (validUnits.indexOf(current) === -1) {
            return defaults;
        }
    }

    return current;
}
