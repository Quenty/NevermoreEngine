local empty = {}
local read_write = { read_only = false }
local read_only = { read_only = true }

local function def_fields(field_list)
   local fields = {}

   for _, field in ipairs(field_list) do
      fields[field] = empty
   end

   return { fields = fields }
end

stds.roblox = {
    globals = {
        script = {
            readonly = true,
            fields = {
                Source = read_write;
                GetHash = read_write;
                Disabled = read_write;
                LinkedSource = read_write;
                CurrentEditor = read_write;
                Archivable = read_write;
                ClassName = read_write;
                DataCost = read_write;
                Name = read_write;
                Parent = read_write;
                RobloxLocked = read_write;
                ClearAllChildren = read_write;
                Clone = read_write;
                Destroy = read_write;
                FindFirstAncestor = read_write;
                FindFirstAncestorOfClass = read_write;
                FindFirstAncestorWhichIsA = read_write;
                FindFirstChild = read_write;
                FindFirstChildOfClass = read_write;
                FindFirstChildWhichIsA = read_write;
                GetChildren = read_write;
                GetDebugId = read_write;
                GetDescendants = read_write;
                GetFullName = read_write;
                GetPropertyChangedSignal = read_write;
                IsA = read_write;
                IsAncestorOf = read_write;
                IsDescendantOf = read_write;
                WaitForChild = read_write;
                AncestryChanged = read_write;
                Changed = read_write;
                ChildAdded = read_write;
                ChildRemoved = read_write;
                DescendantAdded = read_write;
                DescendantRemoving = read_write;
            }
        },
        game = {
            readonly = true,
            fields = {
                CreatorId = read_write;
                CreatorType = read_write;
                GameId = read_write;
                GearGenreSetting = read_write;
                Genre = read_write;
                IsSFFlagsLoaded = read_write;
                JobId = read_write;
                PlaceId = read_write;
                PlaceVersion = read_write;
                PrivateServerId = read_write;
                PrivateServerOwnerId = read_write;
                Workspace = read_write;
                BindToClose = read_write;
                GetJobIntervalPeakFraction = read_write;
                GetJobTimePeakFraction = read_write;
                GetJobsExtendedStats = read_write;
                GetJobsInfo = read_write;
                GetObjects = read_write;
                IsGearTypeAllowed = read_write;
                IsLoaded = read_write;
                Load = read_write;
                OpenScreenshotsFolder = read_write;
                OpenVideosFolder = read_write;
                ReportInGoogleAnalytics = read_write;
                SetPlaceId = read_write;
                SetUniverseId = read_write;
                Shutdown = read_write;
                HttpGetAsync = read_write;
                HttpPostAsync = read_write;
                GraphicsQualityChangeRequest = read_write;
                Loaded = read_write;
                ScreenshotReady = read_write;
                FindService = read_write;
                GetService = read_write;
                Close = read_write;
                CloseLate = read_write;
                ServiceAdded = read_write;
                ServiceRemoving = read_write;
                Archivable = read_write;
                ClassName = read_write;
                DataCost = read_write;
                Name = read_write;
                Parent = read_write;
                RobloxLocked = read_write;
                ClearAllChildren = read_write;
                Clone = read_write;
                Destroy = read_write;
                FindFirstAncestor = read_write;
                FindFirstAncestorOfClass = read_write;
                FindFirstAncestorWhichIsA = read_write;
                FindFirstChild = read_write;
                FindFirstChildOfClass = read_write;
                FindFirstChildWhichIsA = read_write;
                GetChildren = read_write;
                GetDebugId = read_write;
                GetDescendants = read_write;
                GetFullName = read_write;
                GetPropertyChangedSignal = read_write;
                IsA = read_write;
                IsAncestorOf = read_write;
                IsDescendantOf = read_write;
                WaitForChild = read_write;
                AncestryChanged = read_write;
                Changed = read_write;
                ChildAdded = read_write;
                ChildRemoved = read_write;
                DescendantAdded = read_write;
                DescendantRemoving = read_write;
            }
        },
    },
    read_globals = {
        -- Methods
        delay = empty;
        settings = empty;
        spawn = empty;
        tick = empty;
        time = empty;
        typeof = empty;
        version = empty;
        wait = empty;
        warn = empty;

        -- Libraries
        math = def_fields({"abs", "acos", "asin", "atan", "atan2", "ceil", "clamp", "cos", "cosh",
            "deg", "exp", "floor", "fmod", "frexp", "ldexp", "log", "log10", "max", "min", "modf",
            "noise", "pow", "rad", "random", "randomseed", "sign", "sin", "sinh", "sqrt", "tan",
            "tanh", "huge", "pi"}),

        debug = def_fields({"traceback", "profilebegin", "profileend"}),

        -- Types
        Axes = def_fields({"new"}),

        BrickColor = def_fields({"new", "palette", "random", "White", "Gray", "DarkGray", "Black",
            "Red", "Yellow", "Green", "Blue"}),

        CFrame = def_fields({"new", "fromEulerAnglesXYZ", "Angles", "fromOrientation",
            "fromAxisAngle", "fromMatrix"}),

        Color3 = def_fields({"new", "fromRGB", "fromHSV"}),

        ColorSequence = def_fields({"new"}),

        ColorSequenceKeypoint = def_fields({"new"}),

        DockWidgetPluginGuiInfo = def_fields({"new"}),

        Enums = def_fields({"GetEnums"}),

        Faces = def_fields({"new"}),

        Instance = def_fields({"new"}),

        NumberRange = def_fields({"new"}),

        NumberSequence = def_fields({"new"}),

        NumberSequenceKeypoint = def_fields({"new"}),

        PhysicalProperties = def_fields({"new"}),

        Random = def_fields({"new"}),

        Ray = def_fields({"new"}),

        Rect = def_fields({"new"}),

        Region3 = def_fields({"new"}),

        Region3int16 = def_fields({"new"}),

        TweenInfo = def_fields({"new"}),

        UDim = def_fields({"new"}),

        UDim2 = def_fields({"new"}),

        Vector2 = def_fields({"new"}),

        Vector2int16 = def_fields({"new"}),

        Vector3 = def_fields({"new", "FromNormalId", "FromAxis"}),

        Vector3int16 = def_fields({"new"}),

        -- Enums
        Enum = {
            readonly = true,
            fields = {
                ActionType = def_fields({"Nothing", "Pause", "Lose", "Draw", "Win"}),
                ActuatorRelativeTo = def_fields({"Attachment0", "Attachment1", "World"}),
                ActuatorType = def_fields({"None", "Motor", "Servo"}),
                AnimationPriority = def_fields({"Idle", "Movement", "Action", "Core"}),
                AppShellActionType = def_fields({"None", "OpenApp", "TapChatTab",
                    "TapConversationEntry", "TapAvatarTab", "ReadConversation", "TapGamePageTab",
                    "TapHomePageTab", "GamePageLoaded", "HomePageLoaded", "AvatarEditorPageLoaded"}),
                AspectType = def_fields({"FitWithinMaxSize", "ScaleWithParentSize"}),
                AssetType = def_fields({"Image", "TeeShirt", "Audio", "Mesh", "Lua", "Hat",
                    "Place", "Model", "Shirt", "Pants", "Decal", "Head", "Face", "Gear", "Badge",
                    "Animation", "Torso", "RightArm", "LeftArm", "LeftLeg", "RightLeg", "Package",
                    "GamePass", "Plugin", "MeshPart", "HairAccessory", "FaceAccessory",
                    "NeckAccessory", "ShoulderAccessory", "FrontAccessory", "BackAccessory",
                    "WaistAccessory", "ClimbAnimation", "DeathAnimation", "FallAnimation",
                    "IdleAnimation", "JumpAnimation", "RunAnimation", "SwimAnimation",
                    "WalkAnimation", "PoseAnimation", "EarAccessory", "EyeAccessory"}),
                AutoJointsMode = def_fields({"Default", "Explicit", "LegacyImplicit"}),
                AvatarContextMenuOption = def_fields({"Friend", "Chat", "Emote"}),
                AvatarJointPositionType = def_fields({"Fixed", "ArtistIntent"}),
                Axis = def_fields({"X", "Y", "Z"}),
                BinType = def_fields({"Script", "GameTool", "Grab", "Clone", "Hammer"}),
                BodyPart = def_fields({"Head", "Torso", "LeftArm", "RightArm", "LeftLeg",
                    "RightLeg"}),
                BodyPartR15 = def_fields({"Head", "UpperTorso", "LowerTorso", "LeftFoot",
                    "LeftLowerLeg", "LeftUpperLeg", "RightFoot", "RightLowerLeg", "RightUpperLeg",
                    "LeftHand", "LeftLowerArm", "LeftUpperArm", "RightHand", "RightLowerArm",
                    "RightUpperArm", "RootPart", "Unknown"}),
                Button = def_fields({"Jump", "Dismount"}),
                ButtonStyle = def_fields({"Custom", "RobloxButtonDefault", "RobloxButton",
                    "RobloxRoundButton", "RobloxRoundDefaultButton", "RobloxRoundDropdownButton"}),
                CameraMode = def_fields({"Classic", "LockFirstPerson"}),
                CameraPanMode = def_fields({"Classic", "EdgeBump"}),
                CameraType = def_fields({"Fixed", "Watch", "Attach", "Track", "Follow", "Custom",
                    "Scriptable", "Orbital"}),
                CellBlock = def_fields({"Solid", "VerticalWedge", "CornerWedge",
                    "InverseCornerWedge", "HorizontalWedge"}),
                CellMaterial = def_fields({"Empty", "Grass", "Sand", "Brick", "Granite", "Asphalt",
                    "Iron", "Aluminum", "Gold", "WoodPlank", "WoodLog", "Gravel", "CinderBlock",
                    "MossyStone", "Cement", "RedPlastic", "BluePlastic", "Water"}),
                CellOrientation = def_fields({"NegZ", "X", "Z", "NegX"}),
                CenterDialogType = def_fields({"UnsolicitedDialog", "PlayerInitiatedDialog",
                    "ModalDialog", "QuitDialog"}),
                ChatCallbackType = def_fields({"OnCreatingChatWindow", "OnClientSendingMessage",
                    "OnClientFormattingMessage", "OnServerReceivingMessage"}),
                ChatColor = def_fields({"Blue", "Green", "Red", "White"}),
                ChatMode = def_fields({"Menu", "TextAndMenu"}),
                ChatPrivacyMode = def_fields({"AllUsers", "NoOne", "Friends"}),
                ChatStyle = def_fields({"Classic", "Bubble", "ClassicAndBubble"}),
                CollisionFidelity = def_fields({"Default", "Hull", "Box"}),
                ComputerCameraMovementMode = def_fields({"Default", "Follow", "Classic", "Orbital"}),
                ComputerMovementMode = def_fields({"Default", "KeyboardMouse", "ClickToMove"}),
                ConnectionError = def_fields({"OK", "DisconnectErrors", "DisconnectBadhash",
                    "DisconnectSecurityKeyMismatch", "DisconnectNewSecurityKeyMismatch",
                    "DisconnectProtocolMismatch", "DisconnectReceivePacketError",
                    "DisconnectReceivePacketStreamError", "DisconnectSendPacketError",
                    "DisconnectIllegalTeleport", "DisconnectDuplicatePlayer",
                    "DisconnectDuplicateTicket", "DisconnectTimeout", "DisconnectLuaKick",
                    "DisconnectOnRemoteSysStats", "DisconnectHashTimeout",
                    "DisconnectCloudEditKick", "DisconnectPlayerless", "DisconnectEvicted",
                    "DisconnectDevMaintenance", "DisconnectRobloxMaintenance", "DisconnectRejoin",
                    "DisconnectConnectionLost", "DisconnectIdle", "DisconnectRaknetErrors",
                    "DisconnectWrongVersion", "PlacelaunchErrors", "PlacelaunchDisabled",
                    "PlacelaunchError", "PlacelaunchGameEnded", "PlacelaunchGameFull",
                    "PlacelaunchUserLeft", "PlacelaunchRestricted", "PlacelaunchUnauthorized",
                    "PlacelaunchFlooded", "PlacelaunchHashExpired", "PlacelaunchHashException",
                    "PlacelaunchPartyCannotFit", "PlacelaunchHttpError",
                    "PlacelaunchCustomMessage", "PlacelaunchOtherError", "TeleportErrors",
                    "TeleportFailure", "TeleportGameNotFound", "TeleportGameEnded",
                    "TeleportGameFull", "TeleportUnauthorized", "TeleportFlooded",
                    "TeleportIsTeleporting"}),
                ConnectionState = def_fields({"Connected", "Disconnected"}),
                ContextActionPriority = def_fields({"Low", "Medium", "Default", "High"}),
                ContextActionResult = def_fields({"Pass", "Sink"}),
                ControlMode = def_fields({"MouseLockSwitch", "Classic"}),
                CoreGuiType = def_fields({"PlayerList", "Health", "Backpack", "Chat", "All"}),
                CreatorType = def_fields({"User", "Group"}),
                CurrencyType = def_fields({"Default", "Robux", "Tix"}),
                CustomCameraMode = def_fields({"Default", "Follow", "Classic"}),
                DataStoreRequestType = def_fields({"GetAsync", "SetIncrementAsync", "UpdateAsync",
                    "GetSortedAsync", "SetIncrementSortedAsync", "OnUpdate"}),
                DevCameraOcclusionMode = def_fields({"Zoom", "Invisicam"}),
                DevComputerCameraMovementMode = def_fields({"UserChoice", "Classic", "Follow",
                    "Orbital"}),
                DevComputerMovementMode = def_fields({"UserChoice", "KeyboardMouse", "ClickToMove",
                    "Scriptable"}),
                DevTouchCameraMovementMode = def_fields({"UserChoice", "Classic", "Follow",
                    "Orbital"}),
                DevTouchMovementMode = def_fields({"UserChoice", "Thumbstick", "DPad", "Thumbpad",
                    "ClickToMove", "Scriptable", "DynamicThumbstick"}),
                DeveloperMemoryTag = def_fields({"Internal", "HttpCache", "Instances", "Signals",
                    "LuaHeap", "Script", "PhysicsCollision", "PhysicsParts", "GraphicsSolidModels",
                    "GraphicsMeshParts", "GraphicsParticles", "GraphicsParts",
                    "GraphicsSpatialHash", "GraphicsTerrain", "GraphicsTexture",
                    "GraphicsTextureCharacter", "Sounds", "StreamingSounds", "TerrainVoxels",
                    "Gui", "Animation", "Navigation"}),
                DialogBehaviorType = def_fields({"SinglePlayer", "MultiplePlayers"}),
                DialogPurpose = def_fields({"Quest", "Help", "Shop"}),
                DialogTone = def_fields({"Neutral", "Friendly", "Enemy"}),
                DominantAxis = def_fields({"Width", "Height"}),
                EasingDirection = def_fields({"In", "Out", "InOut"}),
                EasingStyle = def_fields({"Linear", "Sine", "Back", "Quad", "Quart", "Quint",
                    "Bounce", "Elastic"}),
                ElasticBehavior = def_fields({"WhenScrollable", "Always", "Never"}),
                EnviromentalPhysicsThrottle = def_fields({"DefaultAuto", "Disabled", "Always",
                    "Skip2", "Skip4", "Skip8", "Skip16"}),
                ErrorReporting = def_fields({"DontReport", "Prompt", "Report"}),
                ExplosionType = def_fields({"NoCraters", "Craters", "CratersAndDebris"}),
                FillDirection = def_fields({"Horizontal", "Vertical"}),
                FilterResult = def_fields({"Rejected", "Accepted"}),
                Font = def_fields({"Legacy", "Arial", "ArialBold", "SourceSans", "SourceSansBold",
                    "SourceSansSemibold", "SourceSansLight", "SourceSansItalic", "Bodoni",
                    "Garamond", "Cartoon", "Code", "Highway", "SciFi", "Arcade", "Fantasy",
                    "Antique"}),
                FontSize = def_fields({"Size8", "Size9", "Size10", "Size11", "Size12", "Size14",
                    "Size18", "Size24", "Size36", "Size48", "Size28", "Size32", "Size42", "Size60",
                    "Size96"}),
                FormFactor = def_fields({"Symmetric", "Brick", "Plate", "Custom"}),
                FrameStyle = def_fields({"Custom", "ChatBlue", "RobloxSquare", "RobloxRound",
                    "ChatGreen", "ChatRed", "DropShadow"}),
                FramerateManagerMode = def_fields({"Automatic", "On", "Off"}),
                FriendRequestEvent = def_fields({"Issue", "Revoke", "Accept", "Deny"}),
                FriendStatus = def_fields({"Unknown", "NotFriend", "Friend", "FriendRequestSent",
                    "FriendRequestReceived"}),
                FunctionalTestResult = def_fields({"Passed", "Warning", "Error"}),
                GameAvatarType = def_fields({"R6", "R15", "PlayerChoice"}),
                GearGenreSetting = def_fields({"AllGenres", "MatchingGenreOnly"}),
                GearType = def_fields({"MeleeWeapons", "RangedWeapons", "Explosives", "PowerUps",
                    "NavigationEnhancers", "MusicalInstruments", "SocialItems", "BuildingTools",
                    "Transport"}),
                Genre = def_fields({"All", "TownAndCity", "Fantasy", "SciFi", "Ninja", "Scary",
                    "Pirate", "Adventure", "Sports", "Funny", "WildWest", "War", "SkatePark",
                    "Tutorial"}),
                GraphicsMode = def_fields({"Automatic", "Direct3D9", "Direct3D11", "OpenGL",
                    "Metal", "Vulkan", "NoGraphics"}),
                HandlesStyle = def_fields({"Resize", "Movement"}),
                HorizontalAlignment = def_fields({"Center", "Left", "Right"}),
                HoverAnimateSpeed = def_fields({"VerySlow", "Slow", "Medium", "Fast", "VeryFast"}),
                HttpCachePolicy = def_fields({"None", "Full", "DataOnly", "Default",
                    "InternalRedirectRefresh"}),
                HttpContentType = def_fields({"ApplicationJson", "ApplicationXml",
                    "ApplicationUrlEncoded", "TextPlain", "TextXml"}),
                HttpError = def_fields({"OK", "InvalidUrl", "DnsResolve", "ConnectFail",
                    "OutOfMemory", "TimedOut", "TooManyRedirects", "InvalidRedirect", "NetFail",
                    "Aborted", "SslConnectFail", "Unknown"}),
                HttpRequestType = def_fields({"Default", "MarketplaceService", "Players", "Chat",
                    "Avatar", "Analytics"}),
                HumanoidDisplayDistanceType = def_fields({"Viewer", "Subject", "None"}),
                HumanoidHealthDisplayType = def_fields({"DisplayWhenDamaged", "AlwaysOn",
                    "AlwaysOff"}),
                HumanoidRigType = def_fields({"R6", "R15"}),
                HumanoidStateType = def_fields({"FallingDown", "Running", "RunningNoPhysics",
                    "Climbing", "StrafingNoPhysics", "Ragdoll", "GettingUp", "Jumping", "Landed",
                    "Flying", "Freefall", "Seated", "PlatformStanding", "Dead", "Swimming",
                    "Physics", "None"}),
                InOut = def_fields({"Edge", "Inset", "Center"}),
                InfoType = def_fields({"Asset", "Product", "GamePass"}),
                InitialDockState = def_fields({"Top", "Bottom", "Left", "Right", "Float"}),
                InputType = def_fields({"NoInput", "Constant", "Sin"}),
                JointCreationMode = def_fields({"All", "Surface", "None"}),
                JointType = def_fields({"None", "Rotate", "RotateP", "RotateV", "Glue", "Weld",
                    "Snap"}),
                KeyCode = def_fields({"Unknown", "Backspace", "Tab", "Clear", "Return", "Pause",
                    "Escape", "Space", "QuotedDouble", "Hash", "Dollar", "Percent", "Ampersand",
                    "Quote", "LeftParenthesis", "RightParenthesis", "Asterisk", "Plus", "Comma",
                    "Minus", "Period", "Slash", "Zero", "One", "Two", "Three", "Four", "Five",
                    "Six", "Seven", "Eight", "Nine", "Colon", "Semicolon", "LessThan", "Equals",
                    "GreaterThan", "Question", "At", "LeftBracket", "BackSlash", "RightBracket",
                    "Caret", "Underscore", "Backquote", "A", "B", "C", "D", "E", "F", "G", "H",
                    "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X",
                    "Y", "Z", "LeftCurly", "Pipe", "RightCurly", "Tilde", "Delete", "KeypadZero",
                    "KeypadOne", "KeypadTwo", "KeypadThree", "KeypadFour", "KeypadFive",
                    "KeypadSix", "KeypadSeven", "KeypadEight", "KeypadNine", "KeypadPeriod",
                    "KeypadDivide", "KeypadMultiply", "KeypadMinus", "KeypadPlus", "KeypadEnter",
                    "KeypadEquals", "Up", "Down", "Right", "Left", "Insert", "Home", "End",
                    "PageUp", "PageDown", "LeftShift", "RightShift", "LeftMeta", "RightMeta",
                    "LeftAlt", "RightAlt", "LeftControl", "RightControl", "CapsLock", "NumLock",
                    "ScrollLock", "LeftSuper", "RightSuper", "Mode", "Compose", "Help", "Print",
                    "SysReq", "Break", "Menu", "Power", "Euro", "Undo", "F1", "F2", "F3", "F4",
                    "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "F13", "F14", "F15",
                    "World0", "World1", "World2", "World3", "World4", "World5", "World6", "World7",
                    "World8", "World9", "World10", "World11", "World12", "World13", "World14",
                    "World15", "World16", "World17", "World18", "World19", "World20", "World21",
                    "World22", "World23", "World24", "World25", "World26", "World27", "World28",
                    "World29", "World30", "World31", "World32", "World33", "World34", "World35",
                    "World36", "World37", "World38", "World39", "World40", "World41", "World42",
                    "World43", "World44", "World45", "World46", "World47", "World48", "World49",
                    "World50", "World51", "World52", "World53", "World54", "World55", "World56",
                    "World57", "World58", "World59", "World60", "World61", "World62", "World63",
                    "World64", "World65", "World66", "World67", "World68", "World69", "World70",
                    "World71", "World72", "World73", "World74", "World75", "World76", "World77",
                    "World78", "World79", "World80", "World81", "World82", "World83", "World84",
                    "World85", "World86", "World87", "World88", "World89", "World90", "World91",
                    "World92", "World93", "World94", "World95", "ButtonX", "ButtonY", "ButtonA",
                    "ButtonB", "ButtonR1", "ButtonL1", "ButtonR2", "ButtonL2", "ButtonR3",
                    "ButtonL3", "ButtonStart", "ButtonSelect", "DPadLeft", "DPadRight", "DPadUp",
                    "DPadDown", "Thumbstick1", "Thumbstick2"}),
                KeywordFilterType = def_fields({"Include", "Exclude"}),
                Language = def_fields({"Default"}),
                LeftRight = def_fields({"Left", "Center", "Right"}),
                LevelOfDetailSetting = def_fields({"High", "Medium", "Low"}),
                Limb = def_fields({"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
                    "Unknown"}),
                ListDisplayMode = def_fields({"Horizontal", "Vertical"}),
                ListenerType = def_fields({"Camera", "CFrame", "ObjectPosition", "ObjectCFrame"}),
                Material = def_fields({"Plastic", "Wood", "Slate", "Concrete", "CorrodedMetal",
                    "DiamondPlate", "Foil", "Grass", "Ice", "Marble", "Granite", "Brick", "Pebble",
                    "Sand", "Fabric", "SmoothPlastic", "Metal", "WoodPlanks", "Cobblestone", "Air",
                    "Water", "Rock", "Glacier", "Snow", "Sandstone", "Mud", "Basalt", "Ground",
                    "CrackedLava", "Neon", "Glass", "Asphalt", "LeafyGrass", "Salt", "Limestone",
                    "Pavement"}),
                MembershipType = def_fields({"None", "BuildersClub", "TurboBuildersClub",
                    "OutrageousBuildersClub"}),
                MeshType = def_fields({"Head", "Torso", "Wedge", "Prism", "Pyramid",
                    "ParallelRamp", "RightAngleRamp", "CornerWedge", "Brick", "Sphere", "Cylinder",
                    "FileMesh"}),
                MessageType = def_fields({"MessageOutput", "MessageInfo", "MessageWarning",
                    "MessageError"}),
                MouseBehavior = def_fields({"Default", "LockCenter", "LockCurrentPosition"}),
                MoveState = def_fields({"Stopped", "Coasting", "Pushing", "Stopping", "AirFree"}),
                NameOcclusion = def_fields({"OccludeAll", "EnemyOcclusion", "NoOcclusion"}),
                NetworkOwnership = def_fields({"Automatic", "Manual", "OnContact"}),
                NormalId = def_fields({"Top", "Bottom", "Back", "Front", "Right", "Left"}),
                OutputLayoutMode = def_fields({"Horizontal", "Vertical"}),
                OverrideMouseIconBehavior = def_fields({"None", "ForceShow", "ForceHide"}),
                PacketPriority = def_fields({"IMMEDIATE_PRIORITY", "HIGH_PRIORITY",
                    "MEDIUM_PRIORITY", "LOW_PRIORITY"}),
                PartType = def_fields({"Ball", "Block", "Cylinder"}),
                PathStatus = def_fields({"Success", "ClosestNoPath", "ClosestOutOfRange",
                    "FailStartNotEmpty", "FailFinishNotEmpty", "NoPath"}),
                PathWaypointAction = def_fields({"Walk", "Jump"}),
                PermissionLevelShown = def_fields({"Game", "RobloxGame", "RobloxScript", "Studio",
                    "Roblox"}),
                Platform = def_fields({"Windows", "OSX", "IOS", "Android", "XBoxOne", "PS4", "PS3",
                    "XBox360", "WiiU", "NX", "Ouya", "AndroidTV", "Chromecast", "Linux", "SteamOS",
                    "WebOS", "DOS", "BeOS", "UWP", "None"}),
                PlaybackState = def_fields({"Begin", "Delayed", "Playing", "Paused", "Completed",
                    "Cancelled"}),
                PlayerActions = def_fields({"CharacterForward", "CharacterBackward",
                    "CharacterLeft", "CharacterRight", "CharacterJump"}),
                PlayerChatType = def_fields({"All", "Team", "Whisper"}),
                PoseEasingDirection = def_fields({"Out", "InOut", "In"}),
                PoseEasingStyle = def_fields({"Linear", "Constant", "Elastic", "Cubic", "Bounce"}),
                PrivilegeType = def_fields({"Owner", "Admin", "Member", "Visitor", "Banned"}),
                ProductPurchaseDecision = def_fields({"NotProcessedYet", "PurchaseGranted"}),
                QualityLevel = def_fields({"Automatic", "Level01", "Level02", "Level03", "Level04",
                    "Level05", "Level06", "Level07", "Level08", "Level09", "Level10", "Level11",
                    "Level12", "Level13", "Level14", "Level15", "Level16", "Level17", "Level18",
                    "Level19", "Level20", "Level21"}),
                R15CollisionType = def_fields({"OuterBox", "InnerBox"}),
                RenderFidelity = def_fields({"Automatic", "Precise"}),
                RenderPriority = def_fields({"First", "Input", "Camera", "Character", "Last"}),
                RenderingTestComparisonMethod = def_fields({"psnr", "diff"}),
                ReverbType = def_fields({"NoReverb", "GenericReverb", "PaddedCell", "Room",
                    "Bathroom", "LivingRoom", "StoneRoom", "Auditorium", "ConcertHall", "Cave",
                    "Arena", "Hangar", "CarpettedHallway", "Hallway", "StoneCorridor", "Alley",
                    "Forest", "City", "Mountains", "Quarry", "Plain", "ParkingLot", "SewerPipe",
                    "UnderWater"}),
                RibbonTool = def_fields({"Select", "Scale", "Rotate", "Move", "Transform",
                    "ColorPicker", "MaterialPicker", "Group", "Ungroup", "None"}),
                RollOffMode = def_fields({"Inverse", "Linear", "InverseTapered", "LinearSquare"}),
                RotationType = def_fields({"MovementRelative", "CameraRelative"}),
                RuntimeUndoBehavior = def_fields({"Aggregate", "Snapshot", "Hybrid"}),
                SaveFilter = def_fields({"SaveAll", "SaveWorld", "SaveGame"}),
                SavedQualitySetting = def_fields({"Automatic", "QualityLevel1", "QualityLevel2",
                    "QualityLevel3", "QualityLevel4", "QualityLevel5", "QualityLevel6",
                    "QualityLevel7", "QualityLevel8", "QualityLevel9", "QualityLevel10"}),
                ScaleType = def_fields({"Stretch", "Slice", "Tile", "Fit", "Crop"}),
                ScreenOrientation = def_fields({"LandscapeLeft", "LandscapeRight",
                    "LandscapeSensor", "Portrait", "Sensor"}),
                ScrollBarInset = def_fields({"None", "ScrollBar", "Always"}),
                ScrollingDirection = def_fields({"X", "Y", "XY"}),
                ServerAudioBehavior = def_fields({"Enabled", "Muted", "OnlineGame"}),
                SizeConstraint = def_fields({"RelativeXY", "RelativeXX", "RelativeYY"}),
                SortOrder = def_fields({"LayoutOrder", "Name", "Custom"}),
                SoundType = def_fields({"NoSound", "Boing", "Bomb", "Break", "Click", "Clock",
                    "Slingshot", "Page", "Ping", "Snap", "Splat", "Step", "StepOn", "Swoosh",
                    "Victory"}),
                SpecialKey = def_fields({"Insert", "Home", "End", "PageUp", "PageDown",
                    "ChatHotkey"}),
                StartCorner = def_fields({"TopLeft", "TopRight", "BottomLeft", "BottomRight"}),
                Status = def_fields({"Poison", "Confusion"}),
                StudioStyleGuideColor = def_fields({"MainBackground", "Titlebar", "Dropdown",
                    "Tooltip", "Notification", "ScrollBar", "ScrollBarBackground", "TabBar", "Tab",
                    "RibbonTab", "RibbonTabTopBar", "Button", "MainButton", "RibbonButton",
                    "ViewPortBackground", "InputFieldBackground", "Item", "TableItem",
                    "CategoryItem", "GameSettingsTableItem", "GameSettingsTooltip", "EmulatorBar",
                    "EmulatorDropDown", "ColorPickerFrame", "CurrentMarker", "Border", "Shadow",
                    "Light", "Dark", "Mid", "MainText", "SubText", "TitlebarText", "BrightText",
                    "DimmedText", "LinkText", "WarningText", "ErrorText", "InfoText",
                    "SensitiveText", "ScriptSideWidget", "ScriptBackground", "ScriptText",
                    "ScriptSelectionText", "ScriptSelectionBackground",
                    "ScriptFindSelectionBackground", "ScriptMatchingWordSelectionBackground",
                    "ScriptOperator", "ScriptNumber", "ScriptString", "ScriptComment",
                    "ScriptPreprocessor", "ScriptKeyword", "ScriptBuiltInFunction",
                    "ScriptWarning", "ScriptError", "DebuggerCurrentLine", "DebuggerErrorLine",
                    "DiffFilePathText", "DiffTextHunkInfo", "DiffTextNoChange", "DiffTextAddition",
                    "DiffTextDeletion", "DiffTextSeparatorBackground",
                    "DiffTextNoChangeBackground", "DiffTextAdditionBackground",
                    "DiffTextDeletionBackground", "DiffLineNum", "DiffLineNumSeparatorBackground",
                    "DiffLineNumNoChangeBackground", "DiffLineNumAdditionBackground",
                    "DiffLineNumDeletionBackground", "DiffFilePathBackground",
                    "DiffFilePathBorder", "Separator", "ButtonBorder", "ButtonText",
                    "InputFieldBorder", "CheckedFieldBackground", "CheckedFieldBorder",
                    "CheckedFieldIndicator", "HeaderSection", "Midlight", "StatusBar"}),
                StudioStyleGuideModifier = def_fields({"Default", "Selected", "Pressed",
                    "Disabled", "Hover"}),
                Style = def_fields({"AlternatingSupports", "BridgeStyleSupports", "NoSupports"}),
                SurfaceConstraint = def_fields({"None", "Hinge", "SteppingMotor", "Motor"}),
                SurfaceType = def_fields({"Smooth", "Glue", "Weld", "Studs", "Inlet", "Universal",
                    "Hinge", "Motor", "SteppingMotor", "SmoothNoOutlines"}),
                SwipeDirection = def_fields({"Right", "Left", "Up", "Down", "None"}),
                TableMajorAxis = def_fields({"RowMajor", "ColumnMajor"}),
                Technology = def_fields({"Legacy", "Voxel"}),
                TeleportResult = def_fields({"Success", "Failure", "GameNotFound", "GameEnded",
                    "GameFull", "Unauthorized", "Flooded", "IsTeleporting"}),
                TeleportState = def_fields({"RequestedFromServer", "Started", "WaitingForServer",
                    "Failed", "InProgress"}),
                TeleportType = def_fields({"ToPlace", "ToInstance", "ToReservedServer"}),
                TextFilterContext = def_fields({"PublicChat", "PrivateChat"}),
                TextTruncate = def_fields({"None", "AtEnd"}),
                TextXAlignment = def_fields({"Left", "Center", "Right"}),
                TextYAlignment = def_fields({"Top", "Center", "Bottom"}),
                TextureMode = def_fields({"Stretch", "Wrap", "Static"}),
                TextureQueryType = def_fields({"NonHumanoid", "NonHumanoidOrphaned", "Humanoid",
                    "HumanoidOrphaned"}),
                ThreadPoolConfig = def_fields({"Auto", "PerCore1", "PerCore2", "PerCore3",
                    "PerCore4", "Threads1", "Threads2", "Threads3", "Threads4", "Threads8",
                    "Threads16"}),
                ThrottlingPriority = def_fields({"Extreme", "ElevatedOnServer", "Default"}),
                ThumbnailSize = def_fields({"Size48x48", "Size180x180", "Size420x420", "Size60x60",
                    "Size100x100", "Size150x150", "Size352x352"}),
                ThumbnailType = def_fields({"HeadShot", "AvatarBust", "AvatarThumbnail"}),
                TickCountSampleMethod = def_fields({"Fast", "Benchmark", "Precise"}),
                TopBottom = def_fields({"Top", "Center", "Bottom"}),
                TouchCameraMovementMode = def_fields({"Default", "Follow", "Classic", "Orbital"}),
                TouchMovementMode = def_fields({"Default", "Thumbstick", "DPad", "Thumbpad",
                    "ClickToMove", "DynamicThumbstick"}),
                TweenStatus = def_fields({"Canceled", "Completed"}),
                UITheme = def_fields({"Light", "Dark"}),
                UiMessageType = def_fields({"UiMessageError", "UiMessageInfo"}),
                UploadSetting = def_fields({"Never", "Ask", "Always"}),
                UserCFrame = def_fields({"Head", "LeftHand", "RightHand"}),
                UserInputState = def_fields({"Begin", "Change", "End", "Cancel", "None"}),
                UserInputType = def_fields({"MouseButton1", "MouseButton2", "MouseButton3",
                    "MouseWheel", "MouseMovement", "Touch", "Keyboard", "Focus", "Accelerometer",
                    "Gyro", "Gamepad1", "Gamepad2", "Gamepad3", "Gamepad4", "Gamepad5", "Gamepad6",
                    "Gamepad7", "Gamepad8", "TextInput", "None"}),
                VRTouchpad = def_fields({"Left", "Right"}),
                VRTouchpadMode = def_fields({"Touch", "VirtualThumbstick", "ABXY"}),
                VerticalAlignment = def_fields({"Center", "Top", "Bottom"}),
                VerticalScrollBarPosition = def_fields({"Left", "Right"}),
                VibrationMotor = def_fields({"Large", "Small", "LeftTrigger", "RightTrigger",
                    "LeftHand", "RightHand"}),
                VideoQualitySettings = def_fields({"LowResolution", "MediumResolution",
                    "HighResolution"}),
                VirtualInputMode = def_fields({"Recording", "Playing", "None"}),
                WaterDirection = def_fields({"NegX", "X", "NegY", "Y", "NegZ", "Z"}),
                WaterForce = def_fields({"None", "Small", "Medium", "Strong", "Max"}),
                ZIndexBehavior = def_fields({"Global", "Sibling"}),
            }
        }
    },
}

stds.testez = {
	read_globals = {
		"describe",
		"it", "itFOCUS", "itSKIP",
		"FOCUS", "SKIP", "HACK_NO_XPCALL",
		"expect",
	}
}

stds.plugin = {
	read_globals = {
		"plugin",
	}
}

ignore = {
	"212", -- unused arguments
}

std = "lua51+roblox"

files["**/*.spec.lua"] = {
	std = "+testez",
}
