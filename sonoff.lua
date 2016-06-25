wifi.setmode(wifi.STATION)
wifi.sta.config("WIFI_NETWORK_NAME","WIFI_PASSWORD")
wifi.sleeptype(wifi.NONE_SLEEP)
wifi.sta.connect()
print(wifi.sta.getip())
print("Status: "..tostring(wifi.sta.status()))

version = "1.0"
relay = 6
led = 7
gpio.mode(relay, gpio.OUTPUT)
gpio.mode(led, gpio.OUTPUT)
gpio.write(led, gpio.HIGH)

gpio.mode(3, gpio.INT)
gpio.trig(3, "down", function(level) 
    if(gpio.read(relay) == 1)then
        gpio.write(relay, gpio.LOW)
        m:publish("/home/sonoff",name.." off",0,0 )
    else
        gpio.write(relay, gpio.HIGH)
        m:publish("/home/sonoff",name.." on",0,0 )
    end
end)

ledstatus = "on"
function toggleLed()
  if(ledstatus == "on") then
    ledstatus = "off"
    gpio.write(led, gpio.HIGH)
  else
    ledstatus = "on"
    gpio.write(led, gpio.LOW)
  end
end


tmr.alarm(0, 500, 1, function()
    if wifi.sta.getip() ~= nil then
       print("Status: "..wifi.sta.status())
       print("IP: "..tostring(wifi.sta.getip()))
       gpio.write(led, gpio.LOW)
       mqcon()
       tmr.stop(0)
    else
       toggleLed()
    end    
end)

name = ""
files = file.list()
if files["device.config"] then
    file.open("device.config", "r")
    name = file.read()
    file.close()
else
    name = "sonoff"
    file.open("device.config", "w+")
    file.write("sonoff")
    file.close()
end

-- Force reconnect to MQTT every hour to fix disconnect problem
tmr.alarm(1, 3600000, tmr.ALARM_AUTO, function() mqcon() end)

-- init mqtt client with keepalive timer 120sec
m = mqtt.Client(name, 120)

m:on("offline", function(client) mqcon() end)

-- on publish message receive event
filetxt = {}
firstpart = false
txtlines = 0
filelines = 0
m:on("message", function(client, topic, data) 
  print(topic .. ":" ) 
  if data ~= nil then
    print(data)
    if(data == "relay on" and topic == "/home/sonoffctl")then
        gpio.write(relay, gpio.HIGH)
        m:publish("/home/sonoff",name.." on",0,0 )
    elseif(data == "relay off" and topic == "/home/sonoffctl")then
        gpio.write(relay, gpio.LOW)
        m:publish("/home/sonoff",name.." off",0,0 )
    elseif(data == "relay status" and topic == "/home/sonoffctl")then
        if(gpio.read(relay) == 1)then
            m:publish("/home/sonoff",name.." on",0,0 )
        else
            m:publish("/home/sonoff",name.." off",0,0 )
        end
    elseif(data == "list" and topic == "/home/sonoffctl")then
        m:publish("/home/sonoff",name.." "..version,0,0 )
    elseif(topic == "/home/sonoffctl/"..name)then
        msg = {}
        for word in string.gmatch(data, "%S+") do
            table.insert(msg, word)
        end

        if(msg[1] == "name")then
            file.open("device.config", "w+")
            file.write(msg[2])
            file.close()
            node.restart()
        elseif(msg[1] == "relay")then
            if(msg[2] == "on")then
                gpio.write(relay, gpio.HIGH)
                m:publish("/home/sonoff",name.." on",0,0 )
            else
                gpio.write(relay, gpio.LOW)
                m:publish("/home/sonoff",name.." off",0,0 )
            end
        end
    elseif(data == "ota" and topic == "/home/sonoffctl/"..name)then
        conn=net.createConnection(net.TCP, false)
        conn:on("receive", function(conn, data)
            print("appending...")
            table.insert(filetxt, data)
            txtlines = txtlines + 1
            
            tmr.alarm(0, 1000, 1, function()
                if txtlines > filelines then
                    filelines = txtlines
                else
                    file.open("sonoff2.lua", "w+")
                    for i, dat in pairs(filetxt) do
                        file.write(dat)
                    end
                    file.close()

                    print("wrote raw data")
                    file.open("sonoff2.lua", "r")
                    -- Read 8 lines out of file to get past http response headers
                    file.readline()
                    file.readline()
                    file.readline()
                    file.readline()
                    file.readline()
                    file.readline()
                    file.readline()
                    file.readline()
                    filetxt = {}
                    t = file.read()
                    while t ~= nil do
                        table.insert(filetxt, t)
                        t = file.read()
                    end
                    
                    file.open("sonoff2.lua", "w+")
                    for i, dat in pairs(filetxt) do
                        file.write(dat)
                    end

                    print("wrote updated text")
                    
                    file.open("update", "w+")
                    file.write("yes")
                    file.close()
                    node.restart()
                    tmr.stop(0)
                end
            end)
        end)
        conn:connect(80,"OTA_HTTP_IP")
        conn:on("connection", function(sck,c)
            file.remove("sonoff2.lua")
            conn:send("GET /sonoff.lua HTTP/1.1\r\nHost: OTA_HTTP_IP\r\n"
                .."Connection: keep-alive\r\nAccept: */*\r\n\r\n")
        end)
    end
  end
end)

print("wifi status: "..wifi.sta.status())

function mqcon()
    m:connect("MQTT_SERVER_IP", 1883, 0,1, function(client)
        m:subscribe("/home/sonoffctl/#",0, function(client) print("subscribe success") end)
        m:publish("/home/sonoff",name.." connected",0,0, function(client) print("announced self") end)
    end, function(client, reason) print("failed reason: "..reason) end)
end

