BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
Describe 'SLT Smart PC Boost Open-Source Repository Integrity' {
    It 'includes all required open-source governance and documentation files' {
        $requiredFiles = @(
            'LICENSE',
            'README.md',
            'SECURITY.md',
            'CONTRIBUTING.md',
            'CODE_OF_CONDUCT.md',
            'CHANGELOG.md',
            'AUTHORS.md',
            'CITATION.cff',
            'SUPPORT.md',
            'docs\PHASE1_SECURITY_HARDENING.md',
            'docs\ARCHITECTURE.md',
            'docs\ROADMAP.md'
        )
        foreach ($rel in $requiredFiles) {
            $full = Join-Path $ProjectRoot $rel
            Test-Path -LiteralPath $full | Should -BeTrue -Because "$rel must exist in the repository"
            (Get-Item -LiteralPath $full).Length | Should -BeGreaterThan 0
        }
    }

    It 'contains a standard OSI MIT license header in LICENSE' {
        $lic = Get-Content -LiteralPath (Join-Path $ProjectRoot 'LICENSE') -Raw
        $lic | Should -Match 'MIT License'
        $lic | Should -Match 'Shahzad Babar'
        $lic | Should -Match 'Smart Life Teck'
        $lic | Should -Match 'Permission is hereby granted, free of charge'
    }

    It 'has valid JSON syntax across all config and data catalogs' {
        $jsonFiles = Get-ChildItem -Path (Join-Path $ProjectRoot 'config'), (Join-Path $ProjectRoot 'data') -Filter *.json -Recurse
        $jsonFiles.Count | Should -BeGreaterThan 0
        foreach ($file in $jsonFiles) {
            { Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json } | Should -Not -Throw -Because "$($file.Name) must be valid JSON"
        }
    }

    It 'has well-formed XML in ui\Main.xaml' {
        $xamlPath = Join-Path $ProjectRoot 'ui\Main.xaml'
        Test-Path -LiteralPath $xamlPath | Should -BeTrue
        { [xml](Get-Content -LiteralPath $xamlPath -Raw) } | Should -Not -Throw
    }

    It 'has zero PowerShell AST syntax errors across all .ps1 scripts' {
        $scripts = Get-ChildItem -Path $ProjectRoot -Filter *.ps1 -Recurse
        $scripts.Count | Should -BeGreaterThan 0
        foreach ($script in $scripts) {
            $tokens = $null
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors)
            $errors.Count | Should -Be 0 -Because "$($script.FullName) should parse cleanly"
        }
    }

    It 'uses unified branding (SLT Smart PC Boost v1.0.0) and Shahzad Babar contact metadata in config\brand.json' {
        $brand = Get-Content -LiteralPath (Join-Path $ProjectRoot 'config\brand.json') -Raw | ConvertFrom-Json
        $brand.AppName | Should -Be 'SLT Smart PC Boost'
        $brand.Version | Should -Be '1.0.0'
        $brand.Developer | Should -Be 'Shahzad Babar'
        $brand.Company | Should -Be 'Smart Life Teck'
    }
}

