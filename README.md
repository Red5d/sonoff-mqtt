# Introduction

This is the code that I use for controlling my [Sonoff](9https://www.itead.cc/sonoff-wifi-wireless-switch.html) esp8266-based devices through MQTT (using node-red). The Sonoffs have been reflashed with NodeMCU so this custom Lua control software can be run on them. See [here](http://tech.scargill.net/itead-slampher-and-sonoff/) for details on reflashing them. These devices incorporate an ESP8266 module, a 120V relay, and a 3.3V power system for the ESP. All for about $5. Much less than the cost of the components separately.

If you have a regular ESP8266 device instead of a Sonoff, you can still use this, but you'll need to change the GPIO pin numbers that the code uses.


# Features

When plugged in, the built-in light on the Sonoff will start blinking as it attempts to connect to the defined WiFi network. It will stop blinking and remain solid once it connects.

Using this code, the following commands can be sent over MQTT to control the device:

Unless otherwise noted, these commands can be sent to either the main control channel (default /home/sonoffctl), or individual devices (like /home/sonoffctl/sonoff1) to control all the devices at once or only specific ones.

####Power Commands - Control the 120V relay on the device. 
######The power status will be sent to the /home/sonoff MQTT topic after these run to confirm the on/off status of the device.
* relay on - Turns relay power on 
* relay off - Turns relay power off

####Other Commands
######These tell the device to send status information or perform other functions that don't affect the relay power.
* relay status - Returns relay status like: "sonoff1 on"
* list - This is sent to /home/sonoffctl (control all devices) and tells all the devices to send their name and software version to the /home/sonoff MQTT topic.
* name <new name> - This is sent to a specific device like /home/sonoffctl/sonoff1. The name defaults to "sonoff", so put new 
devices on the network one at a time and change their names through this command over MQTT before adding more.
* ota - This is sent to a specific device and initiates a transactional update of the code in the sonoff.lua file from the defined web server path.


# Code Architecture and OTA Details

There are two files: init.lua, and sonoff.lua. The NodeMCU firmware runs init.lua on startup. The code checks for a file called "update" in the filesystem and reads it to see if the content is "yes" or "no". 

If yes, that means that an updated sonoff.lua file (the main code) has been downloaded into a file called sonoff2.lua and we can begin the transactional update. It then runs a load and "assert()" operation on the sonoff2.lua file to validate the Lua code in it. 
  
  If this passes, and it's able to load and validate the new code, it overwrites the main sonoff.lua file with the contents of sonoff2.lua to apply the new code, writes "no" to the "update" file, and runs the new code.

  If it fails (some problem with the code like missing punctuation, un-closed parenthesis, etc), then it writes "no" to the "update" file and reboots.
  
If the "update" file contains "no", it continues on the normal process to run the sonoff.lua file.

The point of all this is that unless the code that enables Over The Air updates is modified either before manual upload or during an OTA operation, the code on the device will be able to apply new updates (for additional features or changes) wirelessly without having to plug into it via serial and manually update the code. Also, code with faulty syntax will be rejected so you won't accidently break the code and have to manually re-upload it.

One note on the "version" variable in the sonoff.lua file. This is for if you make changes to the sonoff.lua file and perform an OTA update. Once the update completes and the device is back online, you can send the "list" command out and the sonoff send out its name and version so you can see if the update was successful.

# Installation and Usage

Edit the sonoff.lua file to set the following placeholder text (I'm going to test and reformat some things to move these into easily set variables at the top soon):

* WIFI_NETWORK_NAME
* WIFI_PASSWORD
* OTA_HTTP_IP - Note there are two places where this needs to be changed. Change the HTTP server port and path as well if needed.
* MQTT_SERVER_IP

If you prefer to use different MQTT topics other than the defaults, change those as well.

Flash your Sonoff device with NodeMCU and upload the "init.lua" and "sonoff.lua" files to the device.

Plug the device into power within range of your WiFi and it should connect in a few seconds (indicated by the solid glowing indicator light).

