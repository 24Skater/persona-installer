@{
    # Suppress rules that are noisy for an interactive console app
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',          # we intentionally use colored console output
        'PSUseApprovedVerbs',             # functions like Prompt-Exit are fine here
        'PSUseSingularNouns',             # many of our functions work with collections (Load-Personas, etc.)
        'PSUseShouldProcessForStateChangingFunctions',  # many functions are internal utilities
        'PSAvoidAssignmentToAutomaticVariable',  # $input variable is contextually appropriate
        'PSUseCmdletCorrectly',           # our custom Write-Log doesn't conflict in our context
        'PSReviewUnusedParameter',        # some variables are assigned for readability
        'PSAvoidUsingWMICmdlet',          # used for compatibility checks
        'PSAvoidEmptyCatchBlock'          # some catch blocks are intentionally empty for graceful degradation
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
