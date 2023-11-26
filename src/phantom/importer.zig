pub const imported = if (@hasDecl(@import("root"), "dependencies")) struct {} else blk: {
    const options = @import("phantom.options");
    break :blk if (options.no_importer) struct {} else @import("phantom.imports");
};
