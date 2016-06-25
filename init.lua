function revert()
  print("Update failed. Reverting...")
  file.open("update", "w+")
  file.write("no")
  file.close()
  node.restart()
end

function applynew()
  file.open("sonoff2.lua", "r")
  t = file.read()
  filetxt = {}
  while t ~= nil do
    table.insert(filetxt, t)
    t = file.read()
  end

  file.open("sonoff.lua", "w+")
  for i, dat in pairs(filetxt) do
    file.write(dat)
  end
  file.close()

  file.open("update", "w+")
  file.write("no")
  file.close()
end

function trynew()
  local new = assert(loadfile("sonoff2.lua"))
  applynew() 
  new()
end

files = file.list()
if files["update"] then
    file.open("update", "r")
    if(file.read() == "yes")then
      print("Trying Update: yes")
      xpcall(trynew, revert)
    else
      print("Trying Update: no")
      dofile("sonoff.lua")
    end
else
    file.open("update", "w+")
    file.write("no")
    file.close()
    dofile("sonoff.lua")
end

