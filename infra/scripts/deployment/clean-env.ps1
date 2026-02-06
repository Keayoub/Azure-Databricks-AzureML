# Step 1: Clean up azd state
Remove-Item -Path .azure -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "✓ AZD state cleared"

# Step 2: Verify Azure is clean
$remaining = az group list --query "[?contains(name, 'dbxaml')].name" -o tsv
if ($remaining) {
    Write-Host "❌ Found remaining resources: $remaining"
    Write-Host "Deleting them..."
    $remaining | ForEach-Object { az group delete --name $_ --yes }
}
else {
    Write-Host "✓ Azure is clean"
}

# Step 3: Ready for fresh deployment
Write-Host "✓ Ready for fresh 'azd provision'"