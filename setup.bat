@echo off
REM Roda uma vez so, pra preparar o ambiente.
REM Requer Python 3.9+ instalado e no PATH (teste com: python --version)

echo Criando ambiente virtual...
python -m venv venv

echo Ativando ambiente virtual...
call venv\Scripts\activate.bat

echo Instalando dependencias...
pip install -r requirements.txt

if not exist ".env" (
    echo GEMINI_API_KEY=coloque_sua_chave_aqui > .env
    echo.
    echo Arquivo .env criado. ABRA ELE e coloque sua chave real da API do Gemini.
    echo Pegue a chave em: https://aistudio.google.com/apikey
) else (
    echo Arquivo .env ja existe, nao mexi nele.
)

echo.
echo Setup concluido. Proximo passo: edite o .env com sua chave e rode test_single.bat
pause
