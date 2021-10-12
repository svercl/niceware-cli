# niceware

A Zig port of [niceware](https://github.com/diracdeltas/niceware) with a CLI interface.

See original project README for more information.

## Requirements

- Zig 0.9.0 (tested with version `0.9.0-dev.1324+598db831f`)

## Building

`zig build -Drelease-safe`

## How to use

To get an overview of all commands you can run `niceware --help`.

### from-bytes

Converts from bytes (a hex string) into a passphrase.

`niceware from-bytes e4c320324baf3a03` results in `torpedoed chef fain disabling`

### generate

Generates a random passphrase. You may specify an optional size when calling this command.

### to-bytes

Converts the passphrase into its bytes representation.

`niceware to-bytes stroganoff inharmonic allergic tangy` results in `d7976e08033bde4a`

## Credits

This wouldn't be possible without the [original](https://github.com/diracdeltas/niceware). 

Huge shoutout to healeycodes for the [Rust port](https://github.com/healeycodes/niceware).
The core library used here is a direct port of it.
