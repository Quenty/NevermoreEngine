local empty = {}
local read_write = { read_only = false }
local read_write_class = { read_only = false, other_fields = true }
local read_only = { read_only = true }

local function def_fields(field_list)
   local fields = {}

   for _, field in ipairs(field_list) do
      fields[field] = empty
   end

   return { fields = fields }
end

local enum = def_fields({"Value", "Name"})

local function def_enum(field_list)
   local fields = {}

   for _, field in ipairs(field_list) do
      fields[field] = enum
   end

   fields["GetEnumItems"] = read_only

   return { fields = fields }
end

stds.roblox = {
    globals = {
        script = {
            other_fields = true,
            fields = {
                Source = read_write;
                GetHash = read_write;
                Disabled = read_write;
                LinkedSource = read_write;
                CurrentEditor = read_write_class;
                IsDifferentFromFileSystem = read_write;
                Archivable = read_write;
                ClassName = read_only;
                Name = read_write;
                Parent = read_write_class;
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
                GetAttribute = read_write;
                GetAttributeChangedSignal = read_write;
                GetAttributes = read_write;
                GetChildren = read_write;
                GetDebugId = read_write;
                GetDescendants = read_write;
                GetFullName = read_write;
                GetPropertyChangedSignal = read_write;
                IsA = read_write;
                IsAncestorOf = read_write;
                IsDescendantOf = read_write;
                SetAttribute = read_write;
                WaitForChild = read_write;
                AncestryChanged = read_write;
                AttributeChanged = read_write;
                Changed = read_write;
                ChildAdded = read_write;
                ChildRemoved = read_write;
                DescendantAdded = read_write;
                DescendantRemoving = read_write;
            }
        },
        game = {
            other_fields = true,
            fields = {
                CreatorId = read_only;
                CreatorType = read_only;
                GameId = read_only;
                Genre = read_only;
                IsSFFlagsLoaded = read_only;
                JobId = read_only;
                PlaceId = read_only;
                PlaceVersion = read_only;
                PrivateServerId = read_only;
                PrivateServerOwnerId = read_only;
                Workspace = read_only;
                BindToClose = read_write;
                DefineFastFlag = read_write;
                DefineFastInt = read_write;
                DefineFastString = read_write;
                GetEngineFeature = read_write;
                GetFastFlag = read_write;
                GetFastInt = read_write;
                GetFastString = read_write;
                GetJobIntervalPeakFraction = read_write;
                GetJobTimePeakFraction = read_write;
                GetJobsExtendedStats = read_write;
                GetJobsInfo = read_write;
                GetObjects = read_write;
                GetObjectsList = read_write;
                IsLoaded = read_write;
                Load = read_write;
                OpenScreenshotsFolder = read_write;
                OpenVideosFolder = read_write;
                ReportInGoogleAnalytics = read_write;
                SetFastFlagForTesting = read_write;
                SetFastIntForTesting = read_write;
                SetFastStringForTesting = read_write;
                SetPlaceId = read_write;
                SetUniverseId = read_write;
                Shutdown = read_write;
                GetObjectsAsync = read_write;
                HttpGetAsync = read_write;
                HttpPostAsync = read_write;
                InsertObjectsAndJoinIfLegacyAsync = read_write;
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
                ClassName = read_only;
                Name = read_write;
                Parent = read_write_class;
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
                GetAttribute = read_write;
                GetAttributeChangedSignal = read_write;
                GetAttributes = read_write;
                GetChildren = read_write;
                GetDebugId = read_write;
                GetDescendants = read_write;
                GetFullName = read_write;
                GetPropertyChangedSignal = read_write;
                IsA = read_write;
                IsAncestorOf = read_write;
                IsDescendantOf = read_write;
                SetAttribute = read_write;
                WaitForChild = read_write;
                AncestryChanged = read_write;
                AttributeChanged = read_write;
                Changed = read_write;
                ChildAdded = read_write;
                ChildRemoved = read_write;
                DescendantAdded = read_write;
                DescendantRemoving = read_write;
            }
        },
        workspace = {
            other_fields = true,
            fields = {
                AllowThirdPartySales = read_write;
                CurrentCamera = read_write_class;
                DistributedGameTime = read_write;
                FallenPartsDestroyHeight = read_write;
                FilteringEnabled = read_write;
                Gravity = read_write;
                StreamingEnabled = read_write;
                StreamingMinRadius = read_write;
                StreamingPauseMode = read_write;
                StreamingTargetRadius = read_write;
                TemporaryLegacyPhysicsSolverOverride = read_write;
                Terrain = read_only;
                BreakJoints = read_write;
                CalculateJumpDistance = read_write;
                CalculateJumpHeight = read_write;
                CalculateJumpPower = read_write;
                ExperimentalSolverIsEnabled = read_write;
                GetNumAwakeParts = read_write;
                GetPhysicsThrottling = read_write;
                GetRealPhysicsFPS = read_write;
                JoinToOutsiders = read_write;
                MakeJoints = read_write;
                PGSIsEnabled = read_write;
                SetPhysicsThrottleEnabled = read_write;
                UnjoinFromOutsiders = read_write;
                ZoomToExtents = read_write;
                ArePartsTouchingOthers = read_write;
                BulkMoveTo = read_write;
                FindPartOnRay = read_write;
                FindPartOnRayWithIgnoreList = read_write;
                FindPartOnRayWithWhitelist = read_write;
                FindPartsInRegion3 = read_write;
                FindPartsInRegion3WithIgnoreList = read_write;
                FindPartsInRegion3WithWhiteList = read_write;
                IKMoveTo = read_write;
                IsRegion3Empty = read_write;
                IsRegion3EmptyWithIgnoreList = read_write;
                Raycast = read_write;
                SetInsertPoint = read_write;
                PrimaryPart = read_write_class;
                BreakJoints = read_write;
                GetBoundingBox = read_write;
                GetExtentsSize = read_write;
                GetPrimaryPartCFrame = read_write;
                MakeJoints = read_write;
                MoveTo = read_write;
                SetPrimaryPartCFrame = read_write;
                TranslateBy = read_write;
                Archivable = read_write;
                ClassName = read_only;
                Name = read_write;
                Parent = read_write_class;
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
                GetAttribute = read_write;
                GetAttributeChangedSignal = read_write;
                GetAttributes = read_write;
                GetChildren = read_write;
                GetDebugId = read_write;
                GetDescendants = read_write;
                GetFullName = read_write;
                GetPropertyChangedSignal = read_write;
                IsA = read_write;
                IsAncestorOf = read_write;
                IsDescendantOf = read_write;
                SetAttribute = read_write;
                WaitForChild = read_write;
                AncestryChanged = read_write;
                AttributeChanged = read_write;
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
        UserSettings = empty;

        -- Libraries
        math = def_fields({"abs", "acos", "asin", "atan", "atan2", "ceil", "clamp", "cos", "cosh",
            "deg", "exp", "floor", "fmod", "frexp", "ldexp", "log", "log10", "max", "min", "modf",
            "noise", "pow", "rad", "random", "randomseed", "sign", "sin", "sinh", "sqrt", "tan",
            "tanh", "huge", "pi"}),

        table = def_fields({"concat", "foreach", "foreachi", "getn", "insert", "remove", "sort",
            "pack", "unpack", "move", "create", "find"}),

        os = def_fields({"time", "difftime", "date"}),

        debug = def_fields({"traceback", "profilebegin", "profileend"}),

        utf8 = def_fields({"char", "codes", "codepoint", "len", "offset", "graphemes",
            "nfcnormalize", "nfdnormalize", "charpattern"}),

        bit32 = def_fields({"arshift", "band", "bnot", "bor", "btest", "bxor", "extract",
            "replace", "lrotate", "lshift", "rrotate", "rshift"}),

        string = def_fields({"byte", "char", "find", "format", "gmatch", "gsub", "len", "lower",
            "match", "rep", "reverse", "split"}),

        -- Types
        Axes = def_fields({"new"}),

        BrickColor = def_fields({"new", "palette", "random", "White", "Gray", "DarkGray", "Black",
            "Red", "Yellow", "Green", "Blue"}),

        CFrame = def_fields({"new", "fromEulerAnglesXYZ", "Angles", "fromOrientation",
            "fromAxisAngle", "fromMatrix"}),

        Color3 = def_fields({"new", "fromRGB", "fromHSV", "toHSV"}),

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

        RaycastParams = def_fields({"new"}),

        Rect = def_fields({"new"}),

        Region3 = def_fields({"new"}),

        Region3int16 = def_fields({"new"}),

        TweenInfo = def_fields({"new"}),

        UDim = def_fields({"new"}),

        UDim2 = def_fields({"new", "fromScale", "fromOffset"}),

        Vector2 = def_fields({"new"}),

        Vector2int16 = def_fields({"new"}),

        Vector3 = def_fields({"new", "FromNormalId", "FromAxis"}),

        Vector3int16 = def_fields({"new"}),

        -- Enums
        Enum = {
            readonly = true,
            fields = {
                ABTestLoadingStatus = def_enum({"None", "Pending", "Initialized", "Error",
                    "TimedOut", "ShutOff"}),
                ActionType = def_enum({"Nothing", "Pause", "Lose", "Draw", "Win"}),
                ActuatorRelativeTo = def_enum({"Attachment0", "Attachment1", "World"}),
                ActuatorType = def_enum({"None", "Motor", "Servo"}),
                AlignType = def_enum({"Parallel", "Perpendicular"}),
                AlphaMode = def_enum({"Overlay", "Transparency"}),
                AnimationPriority = def_enum({"Idle", "Movement", "Action", "Core"}),
                AppShellActionType = def_enum({"None", "OpenApp", "TapChatTab",
                    "TapConversationEntry", "TapAvatarTab", "ReadConversation", "TapGamePageTab",
                    "TapHomePageTab", "GamePageLoaded", "HomePageLoaded", "AvatarEditorPageLoaded"}),
                AspectType = def_enum({"FitWithinMaxSize", "ScaleWithParentSize"}),
                AssetFetchStatus = def_enum({"Success", "Failure"}),
                AssetType = def_enum({"Image", "TeeShirt", "Audio", "Mesh", "Lua", "Hat", "Place",
                    "Model", "Shirt", "Pants", "Decal", "Head", "Face", "Gear", "Badge",
                    "Animation", "Torso", "RightArm", "LeftArm", "LeftLeg", "RightLeg", "Package",
                    "GamePass", "Plugin", "MeshPart", "HairAccessory", "FaceAccessory",
                    "NeckAccessory", "ShoulderAccessory", "FrontAccessory", "BackAccessory",
                    "WaistAccessory", "ClimbAnimation", "DeathAnimation", "FallAnimation",
                    "IdleAnimation", "JumpAnimation", "RunAnimation", "SwimAnimation",
                    "WalkAnimation", "PoseAnimation", "EarAccessory", "EyeAccessory",
                    "EmoteAnimation", "Video"}),
                AutoIndentRule = def_enum({"Off", "Absolute", "Relative"}),
                AvatarContextMenuOption = def_enum({"Friend", "Chat", "Emote", "InspectMenu"}),
                AvatarJointPositionType = def_enum({"Fixed", "ArtistIntent"}),
                Axis = def_enum({"X", "Y", "Z"}),
                BinType = def_enum({"Script", "GameTool", "Grab", "Clone", "Hammer"}),
                BodyPart = def_enum({"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"}),
                BodyPartR15 = def_enum({"Head", "UpperTorso", "LowerTorso", "LeftFoot",
                    "LeftLowerLeg", "LeftUpperLeg", "RightFoot", "RightLowerLeg", "RightUpperLeg",
                    "LeftHand", "LeftLowerArm", "LeftUpperArm", "RightHand", "RightLowerArm",
                    "RightUpperArm", "RootPart", "Unknown"}),
                BorderMode = def_enum({"Outline", "Middle", "Inset"}),
                BreakReason = def_enum({"Other", "Error", "UserBreakpoint", "SpecialBreakpoint"}),
                BulkMoveMode = def_enum({"FireAllEvents", "FireCFrameChanged", "FireNoEvents"}),
                Button = def_enum({"Jump", "Dismount"}),
                ButtonStyle = def_enum({"Custom", "RobloxButtonDefault", "RobloxButton",
                    "RobloxRoundButton", "RobloxRoundDefaultButton", "RobloxRoundDropdownButton"}),
                CameraMode = def_enum({"Classic", "LockFirstPerson"}),
                CameraPanMode = def_enum({"Classic", "EdgeBump"}),
                CameraType = def_enum({"Fixed", "Watch", "Attach", "Track", "Follow", "Custom",
                    "Scriptable", "Orbital"}),
                CellBlock = def_enum({"Solid", "VerticalWedge", "CornerWedge",
                    "InverseCornerWedge", "HorizontalWedge"}),
                CellMaterial = def_enum({"Empty", "Grass", "Sand", "Brick", "Granite", "Asphalt",
                    "Iron", "Aluminum", "Gold", "WoodPlank", "WoodLog", "Gravel", "CinderBlock",
                    "MossyStone", "Cement", "RedPlastic", "BluePlastic", "Water"}),
                CellOrientation = def_enum({"NegZ", "X", "Z", "NegX"}),
                CenterDialogType = def_enum({"UnsolicitedDialog", "PlayerInitiatedDialog",
                    "ModalDialog", "QuitDialog"}),
                ChatCallbackType = def_enum({"OnCreatingChatWindow", "OnClientSendingMessage",
                    "OnClientFormattingMessage", "OnServerReceivingMessage"}),
                ChatColor = def_enum({"Blue", "Green", "Red", "White"}),
                ChatMode = def_enum({"Menu", "TextAndMenu"}),
                ChatPrivacyMode = def_enum({"AllUsers", "NoOne", "Friends"}),
                ChatStyle = def_enum({"Classic", "Bubble", "ClassicAndBubble"}),
                CollisionFidelity = def_enum({"Default", "Hull", "Box",
                    "PreciseConvexDecomposition"}),
                ComputerCameraMovementMode = def_enum({"Default", "Follow", "Classic", "Orbital",
                    "CameraToggle"}),
                ComputerMovementMode = def_enum({"Default", "KeyboardMouse", "ClickToMove"}),
                ConnectionError = def_enum({"OK", "DisconnectErrors", "DisconnectBadhash",
                    "DisconnectSecurityKeyMismatch", "DisconnectNewSecurityKeyMismatch",
                    "DisconnectProtocolMismatch", "DisconnectReceivePacketError",
                    "DisconnectReceivePacketStreamError", "DisconnectSendPacketError",
                    "DisconnectIllegalTeleport", "DisconnectDuplicatePlayer",
                    "DisconnectDuplicateTicket", "DisconnectTimeout", "DisconnectLuaKick",
                    "DisconnectOnRemoteSysStats", "DisconnectHashTimeout",
                    "DisconnectCloudEditKick", "DisconnectPlayerless", "DisconnectEvicted",
                    "DisconnectDevMaintenance", "DisconnectRobloxMaintenance", "DisconnectRejoin",
                    "DisconnectConnectionLost", "DisconnectIdle", "DisconnectRaknetErrors",
                    "DisconnectWrongVersion", "DisconnectBySecurityPolicy", "DisconnectBlockedIP",
                    "PlacelaunchErrors", "PlacelaunchDisabled", "PlacelaunchError",
                    "PlacelaunchGameEnded", "PlacelaunchGameFull", "PlacelaunchUserLeft",
                    "PlacelaunchRestricted", "PlacelaunchUnauthorized", "PlacelaunchFlooded",
                    "PlacelaunchHashExpired", "PlacelaunchHashException",
                    "PlacelaunchPartyCannotFit", "PlacelaunchHttpError",
                    "PlacelaunchCustomMessage", "PlacelaunchOtherError", "TeleportErrors",
                    "TeleportFailure", "TeleportGameNotFound", "TeleportGameEnded",
                    "TeleportGameFull", "TeleportUnauthorized", "TeleportFlooded",
                    "TeleportIsTeleporting"}),
                ConnectionState = def_enum({"Connected", "Disconnected"}),
                ContextActionPriority = def_enum({"Low", "Medium", "Default", "High"}),
                ContextActionResult = def_enum({"Pass", "Sink"}),
                ControlMode = def_enum({"MouseLockSwitch", "Classic"}),
                CoreGuiType = def_enum({"PlayerList", "Health", "Backpack", "Chat", "All",
                    "EmotesMenu"}),
                CreatorType = def_enum({"User", "Group"}),
                CurrencyType = def_enum({"Default", "Robux", "Tix"}),
                CustomCameraMode = def_enum({"Default", "Follow", "Classic"}),
                DataStoreRequestType = def_enum({"GetAsync", "SetIncrementAsync", "UpdateAsync",
                    "GetSortedAsync", "SetIncrementSortedAsync", "OnUpdate"}),
                DevCameraOcclusionMode = def_enum({"Zoom", "Invisicam"}),
                DevComputerCameraMovementMode = def_enum({"UserChoice", "Classic", "Follow",
                    "Orbital", "CameraToggle"}),
                DevComputerMovementMode = def_enum({"UserChoice", "KeyboardMouse", "ClickToMove",
                    "Scriptable"}),
                DevTouchCameraMovementMode = def_enum({"UserChoice", "Classic", "Follow",
                    "Orbital"}),
                DevTouchMovementMode = def_enum({"UserChoice", "Thumbstick", "DPad", "Thumbpad",
                    "ClickToMove", "Scriptable", "DynamicThumbstick"}),
                DeveloperMemoryTag = def_enum({"Internal", "HttpCache", "Instances", "Signals",
                    "LuaHeap", "Script", "PhysicsCollision", "PhysicsParts", "GraphicsSolidModels",
                    "GraphicsMeshParts", "GraphicsParticles", "GraphicsParts",
                    "GraphicsSpatialHash", "GraphicsTerrain", "GraphicsTexture",
                    "GraphicsTextureCharacter", "Sounds", "StreamingSounds", "TerrainVoxels",
                    "Gui", "Animation", "Navigation"}),
                DeviceType = def_enum({"Unknown", "Desktop", "Tablet", "Phone"}),
                DialogBehaviorType = def_enum({"SinglePlayer", "MultiplePlayers"}),
                DialogPurpose = def_enum({"Quest", "Help", "Shop"}),
                DialogTone = def_enum({"Neutral", "Friendly", "Enemy"}),
                DominantAxis = def_enum({"Width", "Height"}),
                DraftStatusCode = def_enum({"OK", "DraftOutdated", "ScriptRemoved",
                    "DraftCommitted"}),
                EasingDirection = def_enum({"In", "Out", "InOut"}),
                EasingStyle = def_enum({"Linear", "Sine", "Back", "Quad", "Quart", "Quint",
                    "Bounce", "Elastic", "Exponential", "Circular", "Cubic"}),
                ElasticBehavior = def_enum({"WhenScrollable", "Always", "Never"}),
                EnviromentalPhysicsThrottle = def_enum({"DefaultAuto", "Disabled", "Always",
                    "Skip2", "Skip4", "Skip8", "Skip16"}),
                ExplosionType = def_enum({"NoCraters", "Craters"}),
                FillDirection = def_enum({"Horizontal", "Vertical"}),
                FilterResult = def_enum({"Rejected", "Accepted"}),
                Font = def_enum({"Legacy", "Arial", "ArialBold", "SourceSans", "SourceSansBold",
                    "SourceSansSemibold", "SourceSansLight", "SourceSansItalic", "Bodoni",
                    "Garamond", "Cartoon", "Code", "Highway", "SciFi", "Arcade", "Fantasy",
                    "Antique", "Gotham", "GothamSemibold", "GothamBold", "GothamBlack"}),
                FontSize = def_enum({"Size8", "Size9", "Size10", "Size11", "Size12", "Size14",
                    "Size18", "Size24", "Size36", "Size48", "Size28", "Size32", "Size42", "Size60",
                    "Size96"}),
                FormFactor = def_enum({"Symmetric", "Brick", "Plate", "Custom"}),
                FrameStyle = def_enum({"Custom", "ChatBlue", "RobloxSquare", "RobloxRound",
                    "ChatGreen", "ChatRed", "DropShadow"}),
                FramerateManagerMode = def_enum({"Automatic", "On", "Off"}),
                FriendRequestEvent = def_enum({"Issue", "Revoke", "Accept", "Deny"}),
                FriendStatus = def_enum({"Unknown", "NotFriend", "Friend", "FriendRequestSent",
                    "FriendRequestReceived"}),
                FunctionalTestResult = def_enum({"Passed", "Warning", "Error"}),
                GameAvatarType = def_enum({"R6", "R15", "PlayerChoice"}),
                GearGenreSetting = def_enum({"AllGenres", "MatchingGenreOnly"}),
                GearType = def_enum({"MeleeWeapons", "RangedWeapons", "Explosives", "PowerUps",
                    "NavigationEnhancers", "MusicalInstruments", "SocialItems", "BuildingTools",
                    "Transport"}),
                Genre = def_enum({"All", "TownAndCity", "Fantasy", "SciFi", "Ninja", "Scary",
                    "Pirate", "Adventure", "Sports", "Funny", "WildWest", "War", "SkatePark",
                    "Tutorial"}),
                GraphicsMode = def_enum({"Automatic", "Direct3D9", "Direct3D11", "OpenGL", "Metal",
                    "Vulkan", "NoGraphics"}),
                HandlesStyle = def_enum({"Resize", "Movement"}),
                HorizontalAlignment = def_enum({"Center", "Left", "Right"}),
                HoverAnimateSpeed = def_enum({"VerySlow", "Slow", "Medium", "Fast", "VeryFast"}),
                HttpCachePolicy = def_enum({"None", "Full", "DataOnly", "Default",
                    "InternalRedirectRefresh"}),
                HttpContentType = def_enum({"ApplicationJson", "ApplicationXml",
                    "ApplicationUrlEncoded", "TextPlain", "TextXml"}),
                HttpError = def_enum({"OK", "InvalidUrl", "DnsResolve", "ConnectFail",
                    "OutOfMemory", "TimedOut", "TooManyRedirects", "InvalidRedirect", "NetFail",
                    "Aborted", "SslConnectFail", "SslVerificationFail", "Unknown"}),
                HttpRequestType = def_enum({"Default", "MarketplaceService", "Players", "Chat",
                    "Avatar", "Analytics", "Localization"}),
                HumanoidCollisionType = def_enum({"OuterBox", "InnerBox"}),
                HumanoidDisplayDistanceType = def_enum({"Viewer", "Subject", "None"}),
                HumanoidHealthDisplayType = def_enum({"DisplayWhenDamaged", "AlwaysOn",
                    "AlwaysOff"}),
                HumanoidRigType = def_enum({"R6", "R15"}),
                HumanoidStateType = def_enum({"FallingDown", "Running", "RunningNoPhysics",
                    "Climbing", "StrafingNoPhysics", "Ragdoll", "GettingUp", "Jumping", "Landed",
                    "Flying", "Freefall", "Seated", "PlatformStanding", "Dead", "Swimming",
                    "Physics", "None"}),
                IKCollisionsMode = def_enum({"NoCollisions", "OtherMechanismsAnchored",
                    "IncludeContactedMechanisms"}),
                InOut = def_enum({"Edge", "Inset", "Center"}),
                InfoType = def_enum({"Asset", "Product", "GamePass", "Subscription", "Bundle"}),
                InitialDockState = def_enum({"Top", "Bottom", "Left", "Right", "Float"}),
                InlineAlignment = def_enum({"Bottom", "Center", "Top"}),
                InputType = def_enum({"NoInput", "Constant", "Sin"}),
                JointCreationMode = def_enum({"All", "Surface", "None"}),
                KeyCode = def_enum({"Unknown", "Backspace", "Tab", "Clear", "Return", "Pause",
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
                KeywordFilterType = def_enum({"Include", "Exclude"}),
                Language = def_enum({"Default"}),
                LanguagePreference = def_enum({"SystemDefault", "English", "SimplifiedChinese",
                    "Korean"}),
                LeftRight = def_enum({"Left", "Center", "Right"}),
                LevelOfDetailSetting = def_enum({"High", "Medium", "Low"}),
                Limb = def_enum({"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
                    "Unknown"}),
                ListDisplayMode = def_enum({"Horizontal", "Vertical"}),
                ListenerType = def_enum({"Camera", "CFrame", "ObjectPosition", "ObjectCFrame"}),
                Material = def_enum({"Plastic", "Wood", "Slate", "Concrete", "CorrodedMetal",
                    "DiamondPlate", "Foil", "Grass", "Ice", "Marble", "Granite", "Brick", "Pebble",
                    "Sand", "Fabric", "SmoothPlastic", "Metal", "WoodPlanks", "Cobblestone", "Air",
                    "Water", "Rock", "Glacier", "Snow", "Sandstone", "Mud", "Basalt", "Ground",
                    "CrackedLava", "Neon", "Glass", "Asphalt", "LeafyGrass", "Salt", "Limestone",
                    "Pavement", "ForceField"}),
                MembershipType = def_enum({"None", "BuildersClub", "TurboBuildersClub",
                    "OutrageousBuildersClub", "Premium"}),
                MeshType = def_enum({"Head", "Torso", "Wedge", "Prism", "Pyramid", "ParallelRamp",
                    "RightAngleRamp", "CornerWedge", "Brick", "Sphere", "Cylinder", "FileMesh"}),
                MessageType = def_enum({"MessageOutput", "MessageInfo", "MessageWarning",
                    "MessageError"}),
                ModifierKey = def_enum({"Alt", "Ctrl", "Meta", "Shift"}),
                MouseBehavior = def_enum({"Default", "LockCenter", "LockCurrentPosition"}),
                MoveState = def_enum({"Stopped", "Coasting", "Pushing", "Stopping", "AirFree"}),
                NameOcclusion = def_enum({"OccludeAll", "EnemyOcclusion", "NoOcclusion"}),
                NetworkOwnership = def_enum({"Automatic", "Manual", "OnContact"}),
                NormalId = def_enum({"Top", "Bottom", "Back", "Front", "Right", "Left"}),
                OutputLayoutMode = def_enum({"Horizontal", "Vertical"}),
                OverrideMouseIconBehavior = def_enum({"None", "ForceShow", "ForceHide"}),
                PacketPriority = def_enum({"IMMEDIATE_PRIORITY", "HIGH_PRIORITY",
                    "MEDIUM_PRIORITY", "LOW_PRIORITY"}),
                PartType = def_enum({"Ball", "Block", "Cylinder"}),
                PathStatus = def_enum({"Success", "ClosestNoPath", "ClosestOutOfRange",
                    "FailStartNotEmpty", "FailFinishNotEmpty", "NoPath"}),
                PathWaypointAction = def_enum({"Walk", "Jump"}),
                PermissionLevelShown = def_enum({"Game", "RobloxGame", "RobloxScript", "Studio",
                    "Roblox"}),
                Platform = def_enum({"Windows", "OSX", "IOS", "Android", "XBoxOne", "PS4", "PS3",
                    "XBox360", "WiiU", "NX", "Ouya", "AndroidTV", "Chromecast", "Linux", "SteamOS",
                    "WebOS", "DOS", "BeOS", "UWP", "None"}),
                PlaybackState = def_enum({"Begin", "Delayed", "Playing", "Paused", "Completed",
                    "Cancelled"}),
                PlayerActions = def_enum({"CharacterForward", "CharacterBackward", "CharacterLeft",
                    "CharacterRight", "CharacterJump"}),
                PlayerChatType = def_enum({"All", "Team", "Whisper"}),
                PoseEasingDirection = def_enum({"Out", "InOut", "In"}),
                PoseEasingStyle = def_enum({"Linear", "Constant", "Elastic", "Cubic", "Bounce"}),
                PrivilegeType = def_enum({"Owner", "Admin", "Member", "Visitor", "Banned"}),
                ProductPurchaseDecision = def_enum({"NotProcessedYet", "PurchaseGranted"}),
                QualityLevel = def_enum({"Automatic", "Level01", "Level02", "Level03", "Level04",
                    "Level05", "Level06", "Level07", "Level08", "Level09", "Level10", "Level11",
                    "Level12", "Level13", "Level14", "Level15", "Level16", "Level17", "Level18",
                    "Level19", "Level20", "Level21"}),
                R15CollisionType = def_enum({"OuterBox", "InnerBox"}),
                RaycastFilterType = def_enum({"Blacklist", "Whitelist"}),
                RenderFidelity = def_enum({"Automatic", "Precise"}),
                RenderPriority = def_enum({"First", "Input", "Camera", "Character", "Last"}),
                RenderingTestComparisonMethod = def_enum({"psnr", "diff"}),
                ReturnKeyType = def_enum({"Default", "Done", "Go", "Next", "Search", "Send"}),
                ReverbType = def_enum({"NoReverb", "GenericReverb", "PaddedCell", "Room",
                    "Bathroom", "LivingRoom", "StoneRoom", "Auditorium", "ConcertHall", "Cave",
                    "Arena", "Hangar", "CarpettedHallway", "Hallway", "StoneCorridor", "Alley",
                    "Forest", "City", "Mountains", "Quarry", "Plain", "ParkingLot", "SewerPipe",
                    "UnderWater"}),
                RibbonTool = def_enum({"Select", "Scale", "Rotate", "Move", "Transform",
                    "ColorPicker", "MaterialPicker", "Group", "Ungroup", "None"}),
                RollOffMode = def_enum({"Inverse", "Linear", "InverseTapered", "LinearSquare"}),
                RotationType = def_enum({"MovementRelative", "CameraRelative"}),
                RuntimeUndoBehavior = def_enum({"Aggregate", "Snapshot", "Hybrid"}),
                SaveFilter = def_enum({"SaveAll", "SaveWorld", "SaveGame"}),
                SavedQualitySetting = def_enum({"Automatic", "QualityLevel1", "QualityLevel2",
                    "QualityLevel3", "QualityLevel4", "QualityLevel5", "QualityLevel6",
                    "QualityLevel7", "QualityLevel8", "QualityLevel9", "QualityLevel10"}),
                ScaleType = def_enum({"Stretch", "Slice", "Tile", "Fit", "Crop"}),
                ScreenOrientation = def_enum({"LandscapeLeft", "LandscapeRight", "LandscapeSensor",
                    "Portrait", "Sensor"}),
                ScrollBarInset = def_enum({"None", "ScrollBar", "Always"}),
                ScrollingDirection = def_enum({"X", "Y", "XY"}),
                ServerAudioBehavior = def_enum({"Enabled", "Muted", "OnlineGame"}),
                SizeConstraint = def_enum({"RelativeXY", "RelativeXX", "RelativeYY"}),
                SortOrder = def_enum({"LayoutOrder", "Name", "Custom"}),
                SoundType = def_enum({"NoSound", "Boing", "Bomb", "Break", "Click", "Clock",
                    "Slingshot", "Page", "Ping", "Snap", "Splat", "Step", "StepOn", "Swoosh",
                    "Victory"}),
                SpecialKey = def_enum({"Insert", "Home", "End", "PageUp", "PageDown", "ChatHotkey"}),
                StartCorner = def_enum({"TopLeft", "TopRight", "BottomLeft", "BottomRight"}),
                Status = def_enum({"Poison", "Confusion"}),
                StreamingPauseMode = def_enum({"Default", "Disabled", "ClientPhysicsPause"}),
                StudioDataModelType = def_enum({"Edit", "PlayClient", "PlayServer", "RobloxPlugin",
                    "UserPlugin", "None"}),
                StudioStyleGuideColor = def_enum({"MainBackground", "Titlebar", "Dropdown",
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
                    "ScriptWarning", "ScriptError", "ScriptWhitespace", "ScriptRuler",
                    "DebuggerCurrentLine", "DebuggerErrorLine", "DiffFilePathText",
                    "DiffTextHunkInfo", "DiffTextNoChange", "DiffTextAddition", "DiffTextDeletion",
                    "DiffTextSeparatorBackground", "DiffTextNoChangeBackground",
                    "DiffTextAdditionBackground", "DiffTextDeletionBackground", "DiffLineNum",
                    "DiffLineNumSeparatorBackground", "DiffLineNumNoChangeBackground",
                    "DiffLineNumAdditionBackground", "DiffLineNumDeletionBackground",
                    "DiffFilePathBackground", "DiffFilePathBorder", "Separator", "ButtonBorder",
                    "ButtonText", "InputFieldBorder", "CheckedFieldBackground",
                    "CheckedFieldBorder", "CheckedFieldIndicator", "HeaderSection", "Midlight",
                    "StatusBar", "DialogButton", "DialogButtonText", "DialogButtonBorder",
                    "DialogMainButton", "DialogMainButtonText"}),
                StudioStyleGuideModifier = def_enum({"Default", "Selected", "Pressed", "Disabled",
                    "Hover"}),
                Style = def_enum({"AlternatingSupports", "BridgeStyleSupports", "NoSupports"}),
                SurfaceConstraint = def_enum({"None", "Hinge", "SteppingMotor", "Motor"}),
                SurfaceGuiSizingMode = def_enum({"FixedSize", "PixelsPerStud"}),
                SurfaceType = def_enum({"Smooth", "Glue", "Weld", "Studs", "Inlet", "Universal",
                    "Hinge", "Motor", "SteppingMotor", "SmoothNoOutlines"}),
                SwipeDirection = def_enum({"Right", "Left", "Up", "Down", "None"}),
                TableMajorAxis = def_enum({"RowMajor", "ColumnMajor"}),
                Technology = def_enum({"Compatibility", "Voxel", "ShadowMap", "Legacy"}),
                TeleportResult = def_enum({"Success", "Failure", "GameNotFound", "GameEnded",
                    "GameFull", "Unauthorized", "Flooded", "IsTeleporting"}),
                TeleportState = def_enum({"RequestedFromServer", "Started", "WaitingForServer",
                    "Failed", "InProgress"}),
                TeleportType = def_enum({"ToPlace", "ToInstance", "ToReservedServer"}),
                TextFilterContext = def_enum({"PublicChat", "PrivateChat"}),
                TextInputType = def_enum({"Default", "NoSuggestions", "Number", "Email", "Phone",
                    "Password"}),
                TextTruncate = def_enum({"None", "AtEnd"}),
                TextXAlignment = def_enum({"Left", "Center", "Right"}),
                TextYAlignment = def_enum({"Top", "Center", "Bottom"}),
                TextureMode = def_enum({"Stretch", "Wrap", "Static"}),
                TextureQueryType = def_enum({"NonHumanoid", "NonHumanoidOrphaned", "Humanoid",
                    "HumanoidOrphaned"}),
                ThreadPoolConfig = def_enum({"Auto", "PerCore1", "PerCore2", "PerCore3",
                    "PerCore4", "Threads1", "Threads2", "Threads3", "Threads4", "Threads8",
                    "Threads16"}),
                ThrottlingPriority = def_enum({"Extreme", "ElevatedOnServer", "Default"}),
                ThumbnailSize = def_enum({"Size48x48", "Size180x180", "Size420x420", "Size60x60",
                    "Size100x100", "Size150x150", "Size352x352"}),
                ThumbnailType = def_enum({"HeadShot", "AvatarBust", "AvatarThumbnail"}),
                TickCountSampleMethod = def_enum({"Fast", "Benchmark", "Precise"}),
                TopBottom = def_enum({"Top", "Center", "Bottom"}),
                TouchCameraMovementMode = def_enum({"Default", "Follow", "Classic", "Orbital"}),
                TouchMovementMode = def_enum({"Default", "Thumbstick", "DPad", "Thumbpad",
                    "ClickToMove", "DynamicThumbstick"}),
                TweenStatus = def_enum({"Canceled", "Completed"}),
                UITheme = def_enum({"Light", "Dark"}),
                UiMessageType = def_enum({"UiMessageError", "UiMessageInfo"}),
                UploadSetting = def_enum({"Never", "Ask", "Always"}),
                UserCFrame = def_enum({"Head", "LeftHand", "RightHand"}),
                UserInputState = def_enum({"Begin", "Change", "End", "Cancel", "None"}),
                UserInputType = def_enum({"MouseButton1", "MouseButton2", "MouseButton3",
                    "MouseWheel", "MouseMovement", "Touch", "Keyboard", "Focus", "Accelerometer",
                    "Gyro", "Gamepad1", "Gamepad2", "Gamepad3", "Gamepad4", "Gamepad5", "Gamepad6",
                    "Gamepad7", "Gamepad8", "TextInput", "InputMethod", "None"}),
                VRTouchpad = def_enum({"Left", "Right"}),
                VRTouchpadMode = def_enum({"Touch", "VirtualThumbstick", "ABXY"}),
                VerticalAlignment = def_enum({"Center", "Top", "Bottom"}),
                VerticalScrollBarPosition = def_enum({"Left", "Right"}),
                VibrationMotor = def_enum({"Large", "Small", "LeftTrigger", "RightTrigger",
                    "LeftHand", "RightHand"}),
                VideoQualitySettings = def_enum({"LowResolution", "MediumResolution",
                    "HighResolution"}),
                VirtualInputMode = def_enum({"Recording", "Playing", "None"}),
                WaterDirection = def_enum({"NegX", "X", "NegY", "Y", "NegZ", "Z"}),
                WaterForce = def_enum({"None", "Small", "Medium", "Strong", "Max"}),
                ZIndexBehavior = def_enum({"Global", "Sibling"}),
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
        "DebuggerManager",
    }
}

ignore = {
    "212", -- unused arguments
}

std = "lua51+roblox"

files["**/*.spec.lua"] = {
    std = "+testez",
}