@{
    # Suppress rules that are noisy for an interactive console app
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',   # we intentionally use colored console output
        'PSUseApprovedVerbs'       # functions like Prompt-Exit are fine here
    )

    # Optional formatting preferences (enable if you like)
    # Settings = @{
    #     PSUseConsistentIndentation = @{
    #         Enable = $true
    #         IndentationSize = 2
    #         Kind = 'space'
    #     }
    # }
}
