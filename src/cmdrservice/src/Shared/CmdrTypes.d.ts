export type CmdrLike = Cmdr | CmdrClient;

// stolen from @rbxts/cmdr

interface ArgumentContext {
  /** The command that this argument belongs to. */
  Command: CommandContext;
  /** The name of this argument. */
  Name: string;
  /** The type definition for this argument. */
  Type: TypeDefinition;
  /** Whether or not this argument was required. */
  Required: boolean;
  /** The player that ran the command this argument belongs to. */
  Executor: Player;
  /** The raw, unparsed value for this argument. */
  RawValue: string;
  /** An array of strings representing the values in a comma-separated list, if applicable. */
  RawSegments: Array<string>;
  /** The prefix used in this argument (like `%` in `%Team`). Empty string if no prefix was used. See Prefixed Union Types for more details. */
  Prefix: string;

  /** Returns the parsed value for this argument. */
  GetValue(): unknown;
  /** Returns the _transformed_ value from this argument, see Types. */
  GetTransformedValue(segment: number): unknown;
}

interface Cmdr extends Registry {
  /** Refers to the current command Registry. */
  readonly Registry: Registry;
  /** Refers to the current command Dispatcher. */
  readonly Dispatcher: Dispatcher;
  /** Refers to a table containing many useful utility functions. */
  readonly Util: Util;
}

interface CmdrClient {
  /** Refers to the current command Registry. */
  readonly Registry: Registry;
  /** Refers to the current command Dispatcher. */
  readonly Dispatcher: Dispatcher;
  /** Refers to a table containing many useful utility functions. */
  readonly Util: Util;
  readonly Enabled: boolean;
  readonly PlaceName: string;
  readonly ActivationKeys: Map<Enum.KeyCode, true>;
  /** Sets the key codes that will hide or show Cmdr. */
  SetActivationKeys(keys: Array<Enum.KeyCode>): void;
  /** Sets the place name label that appears when executing commands. This is useful for a quick way to tell what game you're playing in a universe game. */
  SetPlaceName(labelText: string): void;
  /** Sets whether or not Cmdr can be shown via the defined activation keys. Useful for when you want users to need to opt-in to show the console in a settings menu. */
  SetEnabled(isEnabled: boolean): void;
  /** Shows the Cmdr window explicitly. Does not do anything if Cmdr is not enabled. */
  Show(): void;
  /** Hides the Cmdr window. */
  Hide(): void;
  /** Toggles visibility of the Cmdr window. Will not show if Cmdr is not enabled. */
  Toggle(): void;
  HandleEvent(event: string, handler: Callback): void;
  SetMashToEnable(isEnabled: boolean): void;
  SetActivationUnlocksMouse(isEnabled: boolean): void;
  SetHideOnLostFocus(isEnabled: boolean): void;
}

interface CommandContext {
  /** A reference to Cmdr. This may either be the server or client version of Cmdr depending on where the command is running. */
  Cmdr: Cmdr | CmdrClient;
  /** The dispatcher that created this command. */
  Dispatcher: Dispatcher;
  /** The name of the command. */
  Name: string;
  /** The specific alias of this command that was used to trigger this command (may be the same as `Name`) */
  Alias: string;
  /** The raw text that was used to trigger this command. */
  RawText: string;
  /** The group this command is a part of. Defined in command definitions, typically a string. */
  Group: unknown;
  /** A blank table that can be used to store user-defined information about this command's current execution. This could potentially be used with hooks to add information to this table which your command or other hooks could consume. */
  State: {};
  /** Any aliases that can be used to also trigger this command in addition to its name. */
  Aliases: Array<string>;
  /** The description for this command from the command definition. */
  Description: string;
  /** The player who ran this command. */
  Executor: Player;
  /** An array of strings which is the raw value for each argument. */
  RawArguments: Array<string>;
  /** An array of ArgumentContext objects, the parsed equivalent to RawArguments. */
  Arguments: Array<ArgumentContext>;
  /** The command output, if the command has already been run. Typically only accessible in the AfterRun hook. */
  Response: string | undefined;
  /** Returns the ArgumentContext for the given index. */
  GetArgument(index: number): ArgumentContext;
  /** Returns the command data that was sent along with the command. This is the return value of the Data function from the command definition. */
  GetData(): unknown;
  /** Returns a table of the given name. Always returns the same table on subsequent calls. Useful for storing things like ban information. Same as `Registry.GetStore`. */
  GetStore(name: string): {};
  /** Sends a network event of the given name to the given player. See Network Event Handlers. */
  SendEvent(player: Player, event: string): void;
  /** Broadcasts a network event to all players. See Network Event Handlers. */
  BroadcastEvent(event: string, ...args: Array<unknown>): void;
  /** Prints the given text in the user's console. Useful for when a command needs to print more than one message or is long-running. You should still `return` a string from the command implementation when you are finished, `Reply` should only be used to send additional messages before the final message. */
  Reply(text: string, color?: Color3): void;
  /** Returns `true` if the command has an implementation on this machine. For example, this function will return `false` from the client if you call it on a command that only has a server-side implementation. Note that commands can potentially run on both the client and the server, so what this property returns on the server is not related to what it returns on the client, and vice versa. Likewise, receiving a return value of `true` on the client does not mean that the command won't run on the server, because Cmdr commands can run a first part on the client and a second part on the server. This function only answers one question if you run the command; does it run any code as a result of that on this machine? */
  HasImplementation(): boolean;
}

interface Dispatcher {
  /**
   * **CLIENT ONLY**
   *
   * This should be used to invoke commands programmatically as the local player. Accepts a variable number of arguments, which are all joined with spaces before being run. This function will raise an error if any validations occur, since it's only for hard-coded (or generated) commands.
   */
  Run(...names: Array<string>): string;
  /** Runs a command as the given player. If called on the client, only text is required. Returns output or error test as a string. */
  EvaluateAndRun(
    commandText: string,
    executor?: Player,
    options?: {
      Data: unknown;
      IsHuman: boolean;
    }
  ): string;
  /**
   * **CLIENT ONLY**
   *
   * Returns an array of the user's command history. Most recent commands are inserted at the end of the array.
   */
  GetHistory(): Array<string>;
}

interface TypeDefinition {
  /** Optionally overrides the user-facing name of this type in the autocomplete menu. If omitted, the registered name of this type will be used. */
  DisplayName?: string;
  /** String containing default [Prefixed Union Types](https://eryn.io/Cmdr/guide/Commands.html#prefixed-union-types) for this type. This property should omit the initial type name, so this string should begin with a prefix character, e.g. `Prefixes = "# integer ! boolean"`. */
  Prefixes?: string;
  /** Transform is an optional function that is passed two values: the raw text, and the player running the command. Then, whatever values this function returns will be passed to all other functions in the type (`Validate`, `Autocomplete`, and `Parse`). */
  Transform?: (rawText: string, executor: Player) => unknown;
  /**
   * The `Validate` function is passed whatever is returned from the Transform function (or the raw value if there is no Transform function). If the value is valid for the type, it should return `true`. If it the value is invalid, it should return two values: false, and a string containing an error message.
   *
   * If this function isn't present, anything will be considered valid.
   */
  Validate?: (value: unknown) => boolean | LuaTuple<[boolean, string]>;
  /**
   * This function works exactly the same as the normal `Validate` function, except it only runs once (after the user presses Enter). This should only be used if the validation process is relatively expensive or needs to yield. For example, the PlayerId type uses this because it needs to call `GetUserIdFromNameAsync` in order to validate.
   *
   * For the vast majority of types, you should just use `Validate` instead.
   */
  ValidateOnce?: (value: unknown) => boolean | LuaTuple<[boolean, string]>;
  /** Should only be present for types that are possible to be auto completed. It should return an array of strings that will be displayed in the auto complete menu. It can also return a second value, which can be a dictionary with options such as `IsPartial` as described above. */
  Autocomplete?: (
    value: unknown
  ) => Array<string> | LuaTuple<[Array<string>, { IsPartial?: boolean }]>;
  /** Parse is the only required function in a type definition. It is the final step before the value is considered finalized. This function should return the actual parsed value that will be sent to the command functions. */
  Parse: (value: unknown) => unknown;
  /** The `Default` function is optional and should return the "default" value for this type, as a string. For example, the default value of the `players` type is the name of the player who ran the command. */
  Default?: (player: Player) => string;
  /**
   * If you set the optional key `Listable` to `true` in your table, this will tell Cmdr that comma-separated lists are allowed for this type. Cmdr will automatically split the list and parse each segment through your Transform, Validate, Autocomplete, and Parse functions individually, so you don't have to change the logic of your Type at all.
   *
   * The only limitation is that your Parse function **must return a table**. The tables from each individual segment's Parse will be merged into one table at the end of the parse step. The uniqueness of values is ensured upon merging, so even if the user lists the same value several times, it will only appear once in the final table.
   */
  Listable?: boolean;
}

interface CommandArgument {
  /** The argument type (case sensitive), or an inline TypeDefinition object */
  Type: string | TypeDefinition;
  /** The argument name, this is displayed to the user as they type. */
  Name: string;
  /** A description of what the argument is, this is also displayed to the user. */
  Description: string;
  /** If this is present and set to `true`, then the user can run the command without filling out this value. The argument will be sent to your commands as `nil`. */
  Optional?: boolean;
  /** If present, the argument will be optional and if the user doesn't supply a value, your function will receive whatever you set this to. Default being set implies Optional = true, so Optional can be omitted. */
  Default?: unknown;
}

interface CommandDefinition {
  /** The name that's in auto complete and displayed to user. */
  Name: string;
  /** Aliases that are not in the autocomplete, but if matched will run this command just the same. For example, `m` might be an alias of `announce`. */
  Aliases?: Array<string>;
  /** A description of the command which is displayed to the user. */
  Description: string;
  /** Optional, can be be any value you wish. This property is intended to be used in hooks, so that you can categorize commands and decide if you want a specific user to be able to run them or not. */
  Group?: unknown;
  /** Array of `CommandArgument` objects, or functions that return `CommandArgument` objects. */
  Args: Array<CommandArgument | ((context: CommandContext) => CommandArgument)>;
  /** If your command needs to gather some extra data from the client that's only available on the client, then you can define this function. It should accept the CommandContext for the current command as an argument, and return a single value which will be available in the command with [CommandContext.GetData](https://eryn.io/Cmdr/api/CommandContext.html#getdata). */
  Data?: (context: CommandContext, ...args: Array<unknown>) => unknown;
  /**
   * If you want your command to run on the client, you can add this function to the command definition itself. It works exactly like the function that you would return from the Server module.
   *
   * * If this function returns a string, the command will run entirely on the client and won't touch the server (which means server-only hooks won't run).
   * * If this function doesn't return anything, it will fall back to executing the Server module on the server.
   *
   * **WARNING**
   *
   * If this function is present and there isn't a Server module for this command, it is considered an error to not return a string from this function. */
  ClientRun?: (
    context: CommandContext,
    ...args: Array<unknown>
  ) => string | undefined;
  /** A list of commands to run automatically when this command is registered at the start of the game. This should primarily be used to register any aliases regarding this command with the built-in `alias` command, but can be used for initializing state as well. Command execution will be deferred until the end of the frame. */
  AutoExec?: Array<string>;
}

interface Registry {
  /**
   * **SERVER ONLY**
   *
   * Registers all types from within a container.
   */
  RegisterTypesIn(container: Instance): void;
  /** Registers a type. This function should be called from within the type definition ModuleScript. */
  RegisterType(name: string, typeDefinition: TypeDefinition): void;
  /** Registers a [Prefixed Union Type](https://eryn.io/Cmdr/guide/Commands.html#prefixed-union-types) string for the given type. If there are already type prefixes for the given type name, they will be **concatenated**. This allows you to contribute prefixes for default types, like `players`. */
  RegisterTypePrefix(name: string, union: string): void;
  /** Allows you to register a name which will be expanded into a longer type which will can be used as command argument types. For example, if you register the alias `"stringOrNumber"` it could be interpreted as `"string # number"` when used. */
  RegisterTypeAlias(name: string, union: string): void;
  /** Returns a type definition with the given name, or nil if it doesn't exist. */
  GetType(name: string): TypeDefinition | undefined;
  /** Returns a type name taking aliases into account. If there is no alias, the name parameter is simply returned as a pass through. */
  GetTypeName(name: string): string;
  /**
   * **SERVER ONLY**
   *
   * Registers all hooks from within a container on both the server and the client. If you want to add a hook to the server or the client only (not on both), then you should use the [Registry.RegisterHook](https://eryn.io/Cmdr/api/Registry.html#registerhook) method directly by requiring Cmdr in a server or client script.
   */
  RegisterHooksIn(container: Instance): void;
  /**
   * **SERVER ONLY**
   *
   * Registers all commands from within a container.
   */
  RegisterCommandsIn(
    container: Instance,
    filter?: (command: CommandDefinition) => boolean
  ): void;
  /**
   * **SERVER ONLY**
   *
   * Registers an individual command directly from a module script and possible server script. For most cases, you should use [Registry.RegisterCommandsIn](https://eryn.io/Cmdr/api/Registry.html#registercommandsin) instead.
   */
  RegisterCommand(
    commandScript: ModuleScript,
    commandServerScript?: ModuleScript,
    filter?: (command: CommandDefinition) => boolean
  ): void;
  /** Registers the default set of commands. */
  RegisterDefaultCommands(): void;
  RegisterDefaultCommands(groups: Array<string>): void;
  RegisterDefaultCommands(
    filter: (command: CommandDefinition) => boolean
  ): void;
  /** Returns the CommandDefinition of the given name, or nil if not registered. Command aliases are also accepted. */
  GetCommand(name: string): CommandDefinition | undefined;
  /** Returns an array of all commands (aliases not included). */
  GetCommands(): Array<CommandDefinition>;
  /** Returns an array of all command names. */
  GetCommandNames(): Array<string>;
  /** Adds a hook. This should probably be run on the server, but can also work on the client. Hooks run in order of priority (lower number runs first). */
  RegisterHook(
    hookName: 'BeforeRun' | 'AfterRun',
    callback: (context: CommandContext) => string | undefined,
    priority?: number
  ): void;
  /** Returns a table saved with the given name. This is the same as [CommandContext.GetStore](https://eryn.io/Cmdr/api/CommandContext.html#getstore) */
  GetStore(name: string): unknown;
  Cmdr: Cmdr;
}

/** Any object with a `Name` property. */
interface NamedObject {
  Name: string;
}

interface Util {
  /** Accepts an array and flips it into a dictionary, its values becoming keys in the dictionary with the value of `true`. */
  MakeDictionary: <T>(array: Array<T>) => Map<T, true>;
  /** Maps values from one array to a new array. Passes each value through the given callback and uses its return value in the same position in the new array. */
  Map: <T, U>(
    array: Array<T>,
    mapper: (value: T, index: number) => U
  ) => Array<U>;
  /** Maps arguments #2-n through callback and returns all values as tuple. */
  Each: <T, U>(
    mapper: (value: T) => U,
    ...values: Array<T>
  ) => LuaTuple<Array<U>>;
  /** Makes a fuzzy finder for the given set or container. You can pass an array of strings, array of instances, array of EnumItems, array of dictionaries with a Name key or an instance (in which case its children will be used). */
  MakeFuzzyFinder: (
    set:
      | Array<string>
      | Array<Instance>
      | Array<EnumItem>
      | Array<NamedObject>
      | Instance
  ) => (text: string, returnFirst?: boolean) => unknown;
  /** Accepts an array of instances (or anything with a Name property) and maps them into an array of their names. */
  GetNames: (instances: Array<NamedObject>) => Array<string>;
  /** Splits a string into an array split by the given separator. */
  SplitStringSimple: (text: string, separator: string) => Array<string>;
  /** Splits a string by spaces, but taking double-quoted sequences into account which will be treated as a single value. */
  SplitString: (text: string, max?: number) => Array<string>;
  /** Trims whitespace from both sides of a string. */
  TrimString: (text: string) => string;
  /** Returns the text bounds size as a Vector2 based on the given label and optional display size. If size is omitted, the absolute width is used. */
  GetTextSize: (text: string, label: TextLabel, size?: Vector2) => Vector2;
  /** Makes an Enum type out of a name and an array of strings. See Enum Values. */
  MakeEnumType: (
    type: string,
    values: Array<string | NamedObject>
  ) => TypeDefinition;
  /** Takes a singular type and produces a plural (listable) type out of it. */
  MakeListableType: (
    type: TypeDefinition,
    override: Map<unknown, unknown>
  ) => TypeDefinition;
  /**
   * A helper function that makes a type which contains a sequence, like Vector3 or Color3. The delimeter can be either `,` or whitespace, checking `,` first. options is a table that can contain:
   *
   * * `TransformEach`: a function that is run on each member of the sequence, transforming it individually.
   * * `ValidateEach`: a function is run on each member of the sequence validating it. It is passed the value and the index at which it occurs in the sequence. It should return true if it is valid, or false and a string reason if it is not.
   *
   * And one of:
   *
   * * `Parse`: A function that parses all of the values into a single type.
   * * `Constructor`: A function that expects the values unpacked as parameters to create the parsed object. This is a shorthand that allows you to set Constructor directly to Vector3.new, for example.
   */
  MakeSequenceType: (
    options: {
      TransformEach: Callback;
      ValidateEach: Callback;
    } & (
      | {
          Parse: Callback;
        }
      | {
          Constructor: Callback;
        }
    )
  ) => void;
  /** Splits a string by a single delimeter chosen from the given set. The first matching delimeter from the set becomes the split character. */
  SplitPrioritizedDelimeter: (
    text: string,
    delimters: Array<string>
  ) => Array<string>;
  /** Accepts a string with arguments (such as $1, $2, $3, etc) and a table or function to use with string.gsub. Returns a string with arguments replaced with their values. */
  SubstituteArgs: (
    text: string,
    replace:
      | Array<string>
      | Map<string, string>
      | ((variable: string) => string)
  ) => string;
  /** Accepts the current dispatcher and a command string. Parses embedded commands from within the string, evaluating to the output of the command when run with `dispatcher:EvaluateAndRun`. Returns the response string. */
  RunEmbeddedCommands: (
    dispatcher: Dispatcher,
    commandString: string
  ) => string;
  /** Returns a string emulating `\t` tab stops with spaces. */
  EmulateTabstops: (text: string, tabWidth: number) => string;
  /** Replaces escape sequences with their fully qualified characters in a string. This only parses `\n`, `\t`, `\uXXXX`, and `\xXX` where `X` is any hexadecimal character. */
  ParseEscapeSequences: (text: string) => string;
}

declare const Cmdr: Cmdr;
declare const CmdrClient: CmdrClient;
export {
  ArgumentContext,
  Cmdr,
  CmdrClient,
  CommandContext,
  Dispatcher,
  TypeDefinition,
  CommandArgument,
  CommandDefinition,
  Registry,
  NamedObject,
  Util,
};
