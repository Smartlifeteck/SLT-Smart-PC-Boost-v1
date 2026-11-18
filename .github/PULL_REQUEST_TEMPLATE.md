## Summary

Describe the changes in this pull request and link any related issue (`Closes #...`).

## Safety & Quality Checklist

- [ ] Preserves all Phase 1 safety invariants (no hardcoded PINs/secrets, no silent deletions, no BitLocker decryption).
- [ ] Any registry or system modification includes typed backup and rollback support.
- [ ] All `config/*.json` and `data/*.json` changes are valid JSON.
- [ ] Tested locally with `Invoke-Pester -Path .\tests\ -Output Detailed`.
- [ ] No customer records, logs, serial numbers, or temporary `Unattend_*.xml` files are included.

## Testing Notes

- **Windows Version:**
- **PowerShell Version:**
- **Manual Verification Performed:**
