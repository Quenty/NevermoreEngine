while not _G.NevermoreEngine do wait(0) end

local NevermoreEngine   = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;

local qSystems          = LoadCustomLibrary('qSystems')
local qGUI              = LoadCustomLibrary('qGUI')
local PersistantLog     = LoadCustomLibrary('PersistantLog')

qSystems:import(getfenv(0));

local lib = {}

--local PlayerDataContainer     = PersistantLog.AddSubDataLayer("QuentyPlayerData", ServerContainer)

local function GetNotificationObject(Player, Name, TitleName)
	-- Grab's a string value that the PlayerManager uses. 'Name' is the name of the StringValue
	-- Messy. 
	
	Name = Name or "Notification"
	TitleName = TitleName or NotificationTitle
	local PlayerData = PersistantLog.AddSubDataLayer(Player.Name.."Data", PlayerDataBin)
	local Notification = PlayerData:FindFirstChild(Name) or Make 'StringValue' { 
		Name       = Name;
		Value      = "";
		Parent     = PlayerData;
		Archivable = false;
	}
	local NotificationTitle = PlayerData:FindFirstChild("NotificationTitle") or Make 'StringValue' {
		Name       = TitleName;
		Value      = "";
		Parent     = PlayerData;
		Archivable = false;
	}
	return Notification, NotificationTitle
end
lib.GetNotificationObject = GetNotificationObject
lib.getNotificationObject = GetNotificationObject

local MakeNotificationSystem = Class 'NotificationSystem' (function(NotificationSystem, ScreenGui)
	local NotificationId          = 0;
	local Displaying              = false
	local NotificationStateChange = CreateSignal()
	local DefaultAnimateTime      = 0.25

	local function ClearNotifications()
		NotificationId = NotificationId + 1;
		NotificationStateChange:fire()
	end
	NotificationSystem.ClearNotifications = ClearNotifications

	local function ConnectStringValue(StringValue, Title, Icon, AnimationTime)
		-- When the StringValue changes, then it'll notify the player. Title may be a string value.
		return StringValue.Changed:connect(function()
			if StringValue.Value ~= "" then
				local TitleText = Title
				if Title and not type(Title) ~= "string" then
					TitleText = Title.Value
				end
				local Content = StringValue.Value
				StringValue.Value = ""
				NotificationSystem.Notify(Content, Icon, TitleText, true, AnimationTime)
			end
		end)
	end
	NotificationSystem.ConnectStringValue = ConnectStringValue
	NotificationSystem.connectStringValue = ConnectStringValue

	local function Notify(ContentText, IconImage, TitleText, Override, AnimateTime)
		AnimateTime = AnimateTime or DefaultAnimateTime
		IconImage = IconImage or "http://www.roblox.com/asset/?id=116318363"
		TitleText = TitleText or "System Notification";

		if Displaying and Override then
			NotificationId = NotificationId + 1;
		elseif Displaying then
			print("[NotifacationSystem] - Did not display '" .. TitleText .. "'")
			return false;
		end

		print("[NotifacationSystem] - New Notification '" .. TitleText .. "'")
		NotificationId = NotificationId + 1;
		NotificationStateChange:fire()
		Displaying = true
		local LocalNotificationId = NotificationId


		local NotificationFrame = Make 'Frame' {
			Archivable             = false;
			BackgroundColor3       = Color3.new(0, 0, 0);
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Name                   = "qNotification";
			Parent                 = ScreenGui;
			Size                   = UDim2.new(0, 400, 0, 175);
			ZIndex                 = 9;
		}
		--NotificationFrame.Position = UDim2.new(0.5, -NotificationFrame.AbsoluteSize.X/2, 0, -NotificationFrame.AbsoluteSize.Y)--qGUI.GetCenteringPosition(NotificationFrame)
		NotificationFrame.Position = qGUI.GetCenteringPosition(NotificationFrame) + UDim2.new(0, 0, 0, -100);

		local Icon = Make 'Frame' {
			Archivable             = false;
			BackgroundColor3       = Color3.new(0, 0, 0);
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Name                   = "Icon";
			Parent                 = NotificationFrame;
			Position               = UDim2.new(0, 20,  0.5, -70);
			Size                   = UDim2.new(0, 100, 0, 100);
			ZIndex                 = 9;
		}
		qGUI.SetImageId(Icon, IconImage, 10)

		local Title = Make 'TextLabel' {
			Archivable             = false;
			BackgroundColor3       = Color3.new(0, 0, 0);
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Font                   = "ArialBold";
			FontSize               = "Size24";
			Name                   = "Title";
			Parent                 = NotificationFrame;
			Position               = UDim2.new(0, 120,  0, 10);
			Size                   = UDim2.new(1, -120, 0, 40);
			Text                   = "[ Content Deleted ]"; -- In case...
			TextColor3             = qGUI.NewColor3(220, 220, 220);
			TextWrapped            = false;
			TextXAlignment         = "Left";
			TextYAlignment         = "Center";
			ZIndex                 = 10;
			TextTransparency = 1;
		}
		Title.Text = TitleText;

		local Content = Make 'TextLabel' {
			Archivable             = false;
			BackgroundColor3       = Color3.new(0, 0, 0);
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Font                   = "Arial";
			FontSize               = "Size14";
			Name                   = "Content";
			Parent                 = NotificationFrame;
			Position               = UDim2.new(0, 120,  0, 50);
			Size                   = UDim2.new(1, -140, 1, -110);
			Text                   = "[ Content Deleted ]";
			TextColor3             = qGUI.NewColor3(220, 220, 220);
			TextWrapped            = true;
			TextXAlignment         = "Left";
			TextYAlignment         = "Top";
			ZIndex                 = 10;
			TextTransparency = 1;
		}
		Content.Text = ContentText

		local ConfirmButton = Make 'TextButton' {
			Archivable             = false;
			BackgroundColor3       = Color3.new(0, 0, 0);
			BackgroundTransparency = 1; -- Tweens to 0.5
			BorderSizePixel        = 0;
			Font                   = "Arial";
			FontSize               = "Size18";
			Name                   = "ConfirmButton";
			Parent                 = NotificationFrame;
			Position               = UDim2.new(0.5, -100,  1, -45);
			Size                   = UDim2.new(0, 200, 0, 35);
			Text                   = "CLOSE";
			TextColor3             = qGUI.NewColor3(220, 220, 220);	
			TextWrapped            = false;
			TextXAlignment         = "Center";
			TextYAlignment         = "Center";
			ZIndex                 = 10;
		}
		local DidFinish = false

		local Connection = ConfirmButton.MouseButton1Click:connect(function()
			if (not DidFinish) and LocalNotificationId == NotificationId then
				NotificationId = NotificationId + 1
				NotificationStateChange:fire() -- Let's change a few things...
			end
		end)

		local TopLeft, TopRight, BottomLeft, BottomRight, Middle, MiddleLeft, MiddleRight = qGUI.AddTexturedWindowTemplate(NotificationFrame, 14) -- Heh. It works.
		qGUI.SetImageId(TopLeft, "http://www.roblox.com/asset/?id=116183684", 10)
		qGUI.SetImageId(TopRight, "http://www.roblox.com/asset/?id=116183621", 10)
		qGUI.SetImageId(BottomLeft, "http://www.roblox.com/asset/?id=116183704", 10)
		qGUI.SetImageId(BottomRight, "http://www.roblox.com/asset/?id=116183661", 10)

		qGUI.TweenImages(TopLeft, AnimateTime, true, true)
		qGUI.TweenImages(TopRight, AnimateTime, true, true)
		qGUI.TweenImages(BottomLeft, AnimateTime, true, true)
		qGUI.TweenImages(BottomRight, AnimateTime, true, true)
		qGUI.TweenImages(Icon, AnimateTime, true, true)
		
		qGUI.TweenTransparency(Middle, {BackgroundTransparency = 0.6}, AnimateTime, true)
		qGUI.TweenTransparency(MiddleLeft , {BackgroundTransparency = 0.6}, AnimateTime, true)
		qGUI.TweenTransparency(MiddleRight, {BackgroundTransparency = 0.6}, AnimateTime, true)

		qGUI.TweenTransparency(Content, {TextTransparency = 0}, AnimateTime, true)
		qGUI.TweenTransparency(Title, {TextTransparency = 0}, AnimateTime, true)
		qGUI.TweenTransparency(ConfirmButton, {TextTransparency = 0, BackgroundTransparency = 0.5}, AnimateTime, true)
		NotificationFrame:TweenPosition(qGUI.GetCenteringPosition(NotificationFrame), "Out", "Sine", AnimateTime, true)

		while NotificationStateChange:wait(0) and LocalNotificationId == NotificationId do end-- Wait until it's time to close...
		print("[NotifacationSystem] - Hiding Notification")
		DidFinish = true
		Displaying = false;
		Connection:disconnect()

		qGUI.TweenImages(TopLeft, AnimateTime, false, true)
		qGUI.TweenImages(TopRight, AnimateTime, false, true)
		qGUI.TweenImages(BottomLeft, AnimateTime, false, true)
		qGUI.TweenImages(BottomRight, AnimateTime, false, true)
		qGUI.TweenImages(Icon, AnimateTime, false, true)

		qGUI.TweenTransparency(Middle, {BackgroundTransparency = 1}, AnimateTime, true)
		qGUI.TweenTransparency(MiddleLeft , {BackgroundTransparency = 1}, AnimateTime, true)
		qGUI.TweenTransparency(MiddleRight, {BackgroundTransparency = 1}, AnimateTime, true)

		qGUI.TweenTransparency(Content, {TextTransparency = 1}, AnimateTime, true)
		qGUI.TweenTransparency(Title, {TextTransparency = 1}, AnimateTime, true)
		qGUI.TweenTransparency(ConfirmButton, {TextTransparency = 1, BackgroundTransparency = 1}, AnimateTime, true)
		--NotificationFrame:TweenPosition(UDim2.new(0.5, -NotificationFrame.AbsoluteSize.X/2, 0, -NotificationFrame.AbsoluteSize.Y), "In", "Sine", AnimateTime, true)
		NotificationFrame:TweenPosition(qGUI.GetCenteringPosition(NotificationFrame) + UDim2.new(0, 0, 0, -100), "In", "Sine", AnimateTime, true);
		wait(1)
		NotificationFrame:Destroy()
	end
	NotificationSystem.Notify = Notify;
	NotificationSystem.notify = Notify;

end)
lib.MakeNotificationSystem = MakeNotificationSystem
lib.makeNotificationSystem = MakeNotificationSystem

NevermoreEngine.RegisterLibrary('NotificationSystem', lib)

