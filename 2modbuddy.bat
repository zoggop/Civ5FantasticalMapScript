robocopy "C:\Users\zoggop\Documents\my games\Sid Meier's Civilization 5\Maps\Civ5FantasticalMapScript" "C:\Users\zoggop\Documents\Firaxis ModBuddy\Fantastical Map Script\Fantastical Map Script" /E /XF .* /XD .*
"C:\Program Files (x86)\GnuWin32\bin\sed.exe" s/\s(dev)// "C:\Users\zoggop\Documents\Firaxis ModBuddy\Fantastical Map Script\Fantastical Map Script\Fantastical-dev.lua" > "C:\Users\zoggop\Documents\Firaxis ModBuddy\Fantastical Map Script\Fantastical Map Script\Maps\Fantastical.lua"
erase "C:\Users\zoggop\Documents\Firaxis ModBuddy\Fantastical Map Script\Fantastical Map Script\Fantastical-dev.lua"