## What is this?
This is a GUI compass interface and calculator. It's designed to be extendible.

## Dependencies
This section of code does not, as of 5/21/2015, require another other modules outside of its own folder. 

## Example code?
Although there is not loading code or actual GUI elements (for example, `WaitForChild` or `require`), this code here
should give you a good example of how to use this.

```lua
do -- Compass test
	local StripCompass = require("StripCompass")
	local CompassModel = require("CompassModel")

	local CompassGui = WaitForChild(ScreenGui, "Compass")
	
	local Model = CompassModel.new(workspace.CurrentCamera)
	local Compass = StripCompass.new(Model, CompassGui)
	
	do -- ADD ELEMENTS
		local CardinalElement = require("CardinalElement")
		local TemplateGui = WaitForChild(CompassGui, "Template")
		TemplateGui.Parent = nil
		
		local function SetTransparency(self, Transparency)
			self.Gui.TextTransparency = Transparency			
		end
		
		local function AddCardinal(Text, Angle, Number)
			local NewGui = TemplateGui:Clone()
			NewGui.Visible = true
			NewGui.Text = Text or error()
			
			if Number % 4 ~= 0 then
				NewGui.FontSize = "Size18"
				NewGui.Font = "SourceSans"
			end
			
			if Number % 2 ~= 0 then
				NewGui.TextColor3 = Color3.new(0.7, 0.7, 0.7)
			end
			
			Compass:AddElement(
				CardinalElement.new(NewGui, SetTransparency, Angle or error())
			)
		end
		
		local function AddDirections(Directions)
			for Number, Name in pairs(Directions) do
				local Angle = ((Number - 1) / #Directions) * math.pi * 2
				AddCardinal(Name, (-Angle) % (math.pi*2), Number - 1)
			end
		end

		local CompassPositions                   = {"N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"} -- Thanks blocco! Almost did SWW or something.
		local SuperVerboseCompassPositions       = {"Tramontana", "Qto Tramontana verso Greco", "Greco-Tramontana", "Qto Greco verso Tramontana", "Greco", "Qto Greco verso Levante", "Greco-Levante", "Qto Levante verso Greco", "Levante", "Qto Levante verso Scirocco", "Levante-Scirocco", "Qto Scirocco verso Levante", "Scirocco", "Qto Scirocco verso Ostro", "Ostro-Scirocco", "Qto Ostro verso Scirocco", "Ostro", "Qto Ostro verso Libeccio", "Ostro-Libeccio", "Qto Libeccio verso Ostro", "Libeccio", "Qto Libeccio verso Ponente", "Ponente-Libeccio", "Qto Ponente verso Libeccio", "Ponente", "Qto Ponente verso Maestro", "Maestro-Ponente", "Qto Maestro verso Ponente", "Maestro", "Qto Maestro verso Tramontana", "Maestro-Tramontana", "Qto Tramontana verso Maestro"}
		local VerboseCompassPositions            = {"North", "North by east", "North-northeast", "Northeast by north", "Northeast", "Northeast by east", "East-northeast", "East by north", "East", "East by south", "East-southeast", "Southeast by east", "Southeast", "Southeast by south", "South-southeast", "South by east", "South", "South by west", "South-southwest", "Southwest by south", "Southwest", "Southwest by west", "West-southwest", "West by south", "West", "West by north", "West-northwest", "Northwest by west", "Northwest", "Northwest by north", "North-northwest", "North by west"}
		local CorrectCompassPositionsAbbreviated = {"N", "NbE", "NNE", "NEbN", "NE", "NEbE", "ENE", "EbN", "E", "EbS", "ESE", "SEbE", "SE", "SEbS", "SSE", "SbE", "S", "SbW", "SSW", "SWbS", "SW", "SWbW", "WSW", "WbS", "W", "WbN", "WNW", "NWbW", "NW", "NWbN", "NNW", "NbW"}
		
		AddDirections(CorrectCompassPositionsAbbreviated)
		--AddDirections {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
	end
	
	RunService:BindToRenderStep("CompassUpdate", 2000, function()
		Compass:Draw()
	end)
end
```