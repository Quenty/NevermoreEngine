--!strict

export type NamedObject = {
    Name: string
}

export type TypeDefinition<T> = {
    DisplayName: string?,
    Prefixes: string?,
    Transform: ((string, Player) -> T)?,
    Validate: ((T) -> (boolean, string?) | boolean)?,
    ValidateOnce: ((T) -> (boolean, string?) | boolean)?,
    Autocomplete: ((T) -> ({ string }, { IsPartial: boolean? }?) | { string })?,
    Parse: (T) -> any,
    Default: ((Player) -> string)?,
    Listable: boolean?,
}

export type CommandArgument = {
    Type: string | TypeDefinition<any>,
    Name: string,
    Description: string,
    Optional: boolean?,
    Default: any?,
}

export type CommandContext = {
    GetData: (self: CommandContext) -> any,
    GetPlayer: (self: CommandContext) -> Player,
    GetArgs: (self: CommandContext) -> { any },
    GetCommandName: (self: CommandContext) -> string,
    GetCommandId: (self: CommandContext) -> string,
}

export type CommandDefinition = {
    Name: string,
    Aliases: { string }?,
    Description: string,
    Group: any?,
    Args: { CommandArgument | (CommandContext) -> CommandArgument },
    Data: ((CommandContext) -> any)?,
    ClientRun: ((CommandContext, ...any) -> string?)?,
    AutoExec: { string }?,
}

return {}