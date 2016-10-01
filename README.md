# climb.li

CLI micro blogging

This is a simple script to upload image and comments to a server. Climb.li is composed of the font end, which is the index.html, the json content and the images, and a back end publishing tool, which is a simple bash script. 

There is no dependency apart from ssh/scp and sed. 

## Why Bash?

I wanted to create something that doesn't need to be installed, or that doesn't have any dependency apart from really basics tools, so that the script can run on any nix distro. 


## How to install?

In the future, I would like the script to have an install portion (climb -i) which will setup the initial file. At this point you'll have to download the index.html and the script, upload the index.html to your server, setup the script and you're ready to rock. 

All files will be available from http://climb.li for simple retreival. 
