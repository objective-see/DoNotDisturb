# Do Not Disturb

&#x26A0;&nbsp; please note:
```
"Do Not Disturb" (DnD) is currently in alpha. 

This means it is currently under active development and still contains known bugs. 
As such, installing it on any production systems is not recommended at this time! 

```

DnD is a free open-source security tool for macOS that aims to detect unauthorized physical access to your laptop!
Full details and usage instructions can be found [here](https://objective-see.com/products/dnd.html). 

**To Build**<br>
DnD should build cleanly in Xcode (though you will have to remove code signing constraints, or replace with your own Apple developer signing certificate).

**To Install**<br>
For now, DnD must be installed via the command-line. Build Dnd or download the pre-built binaries/components from the [Releases page](https://github.com/objective-see/DnD/releases), then execute the configuration script (`configure.sh`) with the `-install` flag, as root:
```
//install
$ sudo configure.sh -install
```

&#x2764;&nbsp; Love this product or want to support it? Check out my [patreon page](https://www.patreon.com/objective_see) :)

**Mahalo!**<br>
This product is supported by the following patrons:
+ Lance Gaines
+ Ash Morgan
+ Khalil Sehnaoui
+ Nando Mendonca
+ Bill Smartt
+ Martin OConnell
+ David Sulpy
+ Shain Singh
+ Chad Collins
+ Harry Hoffman
+ Keelian Wardle
+ Christopher Giffard
+ Conrad Rushing
+ soreq
+ Stuart Ashenbrenner
+ trifero
+ Peter Sinclair
+ Ming
+ Gamer Bot
