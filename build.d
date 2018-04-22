#!/usr/bin/rdmd

import std.algorithm;
import std.array;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.getopt;

void run(string cmd)
{
    writeln(cmd);
    auto result = executeShell(cmd);
    writeln(result.output);
}

void main(string[] args)
{
    string compiler;

    auto result = getopt
    (
        args,
        "compiler|c", "The compiler to use (gdc or ldc)", &compiler
    );

    if (result.helpWanted || args.length < 1 || (compiler != "gdc" && compiler != "ldc"))
    {
        writefln("USAGE: -c=gdc|ldc", args[0]);
        writeln();
        write("options:");
        defaultGetoptPrinter("", result.options);

        return;
    }

    auto sourceDir = "source";
    auto binaryDir = "binary";
    auto objectFile = buildPath(binaryDir, "firmware.o");
    auto outputFile = buildPath(binaryDir, "firmware");

    // Create any directories that may not exist
    if (!binaryDir.exists())
    {
        mkdir(binaryDir);
    }

    // remove any intermediate files
    auto cmd = "rm -f " ~ binaryDir ~ "/*";
    run(cmd);

	auto sourceFiles = sourceDir
		.dirEntries("*.d", SpanMode.depth)
		.filter!(a => !a.name.startsWith("source/runtime")) // runtime will be imported automatically
		.map!"a.name"
		.join(" ");

    if (compiler == "gdc")
    {
        // compile to temporary assembly file
        cmd = "arm-none-eabi-gdc -c -Os -nophoboslib -nostdinc -nodefaultlibs -nostdlib"
            ~ " -mthumb -mcpu=cortex-m4 -mtune=cortex-m4"
            ~ " -Isource/runtime" // to import runtime automatically
            ~ " -fno-bounds-check -fno-invariants" // -fno-assert gives me a broken binary
            ~ " -ffunction-sections"
            ~ " -fdata-sections"
            ~ " -fno-weak"

            ~ " " ~ sourceFiles
            ~ " -o " ~ objectFile;
    }
    else if (compiler == "ldc")
    {
        // compile to temporary assembly file
        cmd = "ldc2 -c -Os -mtriple=thumb-none-eabi -float-abi=hard"
            ~ " -mcpu=cortex-m4"
            ~ " -Isource/runtime" // to import runtime automatically

            ~ " " ~ sourceFiles
            ~ " -of=" ~ objectFile;
    }
    else
    {
        assert(false);
    }
    run(cmd);

    // link, creating executable
    cmd = "arm-none-eabi-ld " ~ objectFile ~ " -Tlinker/linker.ld --gc-sections -o " ~ outputFile;
    run(cmd);

    // display the size
    run("arm-none-eabi-size " ~ outputFile);
}
