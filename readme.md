# generalized project compressor
optionally depends on luamin (should be in your repositories on linux)<br>
and [vfstool-rs](https://github.com/walksanatora/imgtool-rs)<br>
luamin minified lua reducing output file size of non-luz compressed files<br>
vfstool generates a Self Extracting Archive for use in CC that is meant to be easily uploaded

to use, probally put this in some computercraft folder in my local one it is computer 20 (it will autodetect)<br>
just make sure that ../.. is read/write since we gonna be running CCPC on this (also... make sure the folder is a number)<br>
sym-link or hard link or whatever your main file and dependecies<br>
change line 27 to point to the "entrypoint" which is how it will generate the requires from<br>
then just run build.sh and it will put minified dependecies in `exported` (and if you have vfstool it will produce project.sea in the root)<br>