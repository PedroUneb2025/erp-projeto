$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw "Instale e abra o Docker Desktop antes de continuar." }
docker info | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Abra o Docker Desktop e aguarde iniciar." }
if (-not (Test-Path ".env")) {
  $content = Get-Content ".env.example" -Raw
  foreach ($key in @("POSTGRES","APP","BI","METABASE","MONGO","JWT")) {
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes); $rng.Dispose()
    $value = -join ($bytes | ForEach-Object { $_.ToString("x2") })
    $content = $content.Replace("CHANGE_ME_$key", $value)
  }
  [IO.File]::WriteAllText((Join-Path $PSScriptRoot ".env"), $content)
}
docker compose up -d --build
if ($LASTEXITCODE -ne 0) { throw "Falha ao iniciar. Execute docker compose logs --tail=80." }
Write-Host "Acompanhe com: docker compose ps"
Write-Host "Painel: http://localhost:5173 | API: http://localhost:8000/docs | Metabase: http://localhost:3000"
Write-Host "O login fica pendente ate integrar o cadastro real de usuarios. Leia COMECE_AQUI.md."
