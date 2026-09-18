@{
    # Settings for PSScriptAnalyzer.

    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        # Why this rule is turned off:
        #
        # PSAvoidUsingWriteHost tells you to use Write-Output instead of
        # Write-Host. That is good advice for a function that returns data
        # into a pipeline, because Write-Host output cannot be captured.
        #
        # These scripts are different. They are tools a person runs in a
        # console and reads with their eyes. The coloured lines (green for
        # fine, yellow for a problem) are the point of them. If we switched
        # to Write-Output, the status lines would mix into the real data and
        # break anyone who pipes the result somewhere.
        #
        # The data itself is never sent with Write-Host. Every script returns
        # proper objects, writes a CSV or HTML file with -OutputPath, and sets
        # an exit code, so automation has clean ways to read the result.
        'PSAvoidUsingWriteHost'
    )
}
