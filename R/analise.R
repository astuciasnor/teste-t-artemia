# CRESCIMENTO DE ARTEMIA SOB DUAS RAÇÕES — ROTEIRO DE ANÁLISE
# x========================================================================x
# Pergunta: a taxa de crescimento da Artemia difere entre as rações A e B?
# Desenho: delineamento inteiramente casualizado (DIC), dois tratamentos e
# 7 réplicas por ração (14 aquários). Cada aquário é uma unidade independente.
#
# COMO ESTUDAR
# Abra teste-t-artemia.Rproj e execute as seções na ordem, de cima para baixo.
# No RStudio, Ctrl+Enter executa a linha ou a seleção. Digite o nome de um
# objeto no console para examiná-lo, por exemplo: tabela_teste.
# O sumário do editor (Ctrl+Shift+O) permite navegar entre as seções numeradas.
#
# MAPA DO ROTEIRO
#  1–3. Preparar o ambiente, ler a planilha e organizar os dois grupos.
#  4–6. Explorar, conferir os pressupostos e aplicar o teste t.
#  7–8. Preparar as tabelas e construir os gráficos.
#    9. Preparar os textos que serão usados nos relatórios.
# 10–11. Salvar cópias dos resultados e registrar as versões utilizadas.
#
# OBJETOS QUE OS RELATÓRIOS VÃO USAR
# dados                      base com as duas colunas, ração já como fator
# teste_t                    resultado do t.test escolhido conforme as variâncias
# d_cohen                    tamanho do efeito (referência estatística)
# tabela_descritiva_exibir   resumo por grupo, formatado
# tabela_teste               método, diferença, IC, t, gl, p e d, formatados
# grafico_caixa              boxplot com os pontos de cada aquário
# texto_resultado            frase com o resultado do teste
#
# Cada QMD executa este script numa sessão nova e usa os objetos em memória.
# Edite os cálculos aqui e a argumentação científica nos documentos Quarto.
# Instale os pacotes uma única vez conforme o README, antes de executar.

# 1. Preparar o ambiente ---------------------------------------------------
library(here)
# Declara: "este arquivo está em R/analise.R, dentro do meu projeto".
# Assim, here() monta caminhos a partir da raiz do projeto. Abra o .Rproj antes.
here::i_am("R/analise.R")
library(dplyr)
library(ggplot2)
library(flextable)
# As funções abaixo cuidam da apresentação; os cálculos ficam neste script.
source(here::here("R", "funcoes.R"), encoding = "UTF-8")

# 2. Definir as escolhas e ler os dados ------------------------------------
# Os nomes entre aspas devem corresponder exatamente às colunas da planilha.
variavel_resposta <- "taxa_crescimento_mg_dia"
variavel_grupo <- "racao"
# Rótulos são textos de apresentação; alterá-los não renomeia as colunas.
rotulo_resposta <- "Taxa de crescimento (mg/dia)"
rotulo_grupo <- "Ração"
# Rótulos amigáveis de cada nível, usados nas tabelas e nos textos.
rotulos_niveis <- c(A = "A (farelo de arroz)", B = "B (farelo de babaçu)")
nivel_confianca <- 0.95
alfa <- 1 - nivel_confianca

# Estas pastas guardam produtos regeneráveis. Os dados brutos ficam intactos.
for (pasta in c("dados/processados", "saida/tabelas", "saida/figuras", "saida/relatorios")) {
  dir.create(here::here(pasta), showWarnings = FALSE, recursive = TRUE)
}

# Ler a planilha local: cada linha é um aquário (uma réplica).
# read.csv2 entende o padrão brasileiro: ; separa colunas e a vírgula é decimal.
# A cópia local permite trabalhar só com pacotes do CRAN, sem instalar EAPADados.
# Alternativa, se o pacote estiver instalado:
# dados_brutos <- EAPADados::artemia
dados_brutos <- read.csv2(
  here::here("dados", "brutos", "artemia.csv"),
  stringsAsFactors = FALSE,
  encoding = "UTF-8"
)

# 3. Preparar a base -------------------------------------------------------
# factor() marca a ração como categoria; fixamos a ordem dos níveis (A, B) para
# que a diferença do teste seja lida como "média de A menos média de B".
# row_number() numera os aquários, útil para localizar uma réplica na planilha.
dados <- dados_brutos |>
  mutate(
    racao = factor(racao, levels = c("A", "B")),
    numero_aquario = row_number()
  )

# Conferências mínimas antes de analisar: dois grupos, sem faltantes, com variação.
if (nlevels(dados$racao) != 2) stop("O teste t compara exatamente dois grupos.")
if (anyNA(dados[[variavel_resposta]])) stop("Há valores ausentes na resposta; confira a planilha.")
# split() separa a resposta por ração; assim conferimos cada grupo isoladamente.
grupos <- split(dados[[variavel_resposta]], dados$racao)
if (any(lengths(grupos) < 2)) stop("Cada grupo precisa de pelo menos duas observações.")
if (any(vapply(grupos, function(x) length(unique(x)) < 2, logical(1)))) {
  stop("A resposta precisa variar dentro de cada grupo.")
}
n_total <- nrow(dados)

# 4. Explorar: resumo por grupo --------------------------------------------
# Uma linha por ração com n, média, desvio padrão, erro padrão e amplitude.
# O DP mede a dispersão entre aquários; o EP mede a incerteza da média do grupo.
tabela_descritiva <- dados |>
  group_by(racao) |>
  summarise(
    n = dplyr::n(),
    media = mean(.data[[variavel_resposta]]),
    dp = sd(.data[[variavel_resposta]]),
    ep = dp / sqrt(n),
    minimo = min(.data[[variavel_resposta]]),
    maximo = max(.data[[variavel_resposta]]),
    .groups = "drop"
  )
# Versão formatada para exibição, com rótulos amigáveis e vírgula decimal.
tabela_descritiva_exibir <- tabela_descritiva |>
  transmute(
    Ração = rotulos_niveis[as.character(racao)],
    n = n,
    Média = fmt(media),
    DP = fmt(dp),
    EP = fmt(ep),
    Mínimo = fmt(minimo),
    Máximo = fmt(maximo)
  )

# 5. Conferir os pressupostos ----------------------------------------------
# O teste t clássico pede normalidade DENTRO de cada grupo e variâncias
# parecidas ENTRE os grupos. Com amostras pequenas, usamos Shapiro-Wilk por
# grupo e o teste F para a igualdade de variâncias.
# tapply aplica shapiro.test a cada grupo e guarda o p-valor de cada um.
p_shapiro <- tapply(dados[[variavel_resposta]], dados$racao,
                    function(x) shapiro.test(x)$p.value)
p_shapiro_A <- p_shapiro[["A"]]
p_shapiro_B <- p_shapiro[["B"]]
# var.test compara as variâncias dos dois grupos (teste F).
teste_variancia <- var.test(
  reformulate(variavel_grupo, response = variavel_resposta),
  data = dados
)
p_variancia <- teste_variancia$p.value
# Decisão honesta: só tratamos as variâncias como iguais quando o teste F NÃO
# dá evidência de diferença (p maior ou igual a alfa).
variancias_iguais <- p_variancia >= alfa
# A normalidade fica "ok" quando nenhum dos dois grupos dá evidência de desvio.
normalidade_ok <- all(p_shapiro >= alfa)

# 6. Aplicar o teste t -----------------------------------------------------
# A escolha do método segue o teste F: variâncias iguais levam ao t de Student;
# variâncias diferentes levam ao t de Welch. Guardamos os dois para comparar.
formula_teste <- reformulate(variavel_grupo, response = variavel_resposta)
teste_t <- t.test(formula_teste, data = dados, var.equal = variancias_iguais)
teste_welch <- t.test(formula_teste, data = dados, var.equal = FALSE)
# Nome do método em português, para as tabelas e o texto.
metodo_teste <- if (variancias_iguais) "t de Student (variâncias iguais)" else "t de Welch (variâncias diferentes)"

# Médias de cada ração e a diferença entre elas (A menos B), com seu IC.
media_A <- tabela_descritiva$media[tabela_descritiva$racao == "A"]
media_B <- tabela_descritiva$media[tabela_descritiva$racao == "B"]
diferenca_medias <- media_A - media_B
ic_diferenca <- teste_t$conf.int

# Tamanho do efeito (d de Cohen) calculado à mão, para ficar transparente.
# sp é o desvio padrão combinado: pondera a variância de cada grupo pelos
# seus graus de liberdade (n - 1). O d mede a diferença em desvios padrão.
n_A <- tabela_descritiva$n[tabela_descritiva$racao == "A"]
n_B <- tabela_descritiva$n[tabela_descritiva$racao == "B"]
dp_A <- tabela_descritiva$dp[tabela_descritiva$racao == "A"]
dp_B <- tabela_descritiva$dp[tabela_descritiva$racao == "B"]
sp <- sqrt(((n_A - 1) * dp_A^2 + (n_B - 1) * dp_B^2) / (n_A + n_B - 2))
d_cohen <- diferenca_medias / sp
classe_efeito <- rotular_efeito(d_cohen)

# 7. Preparar as tabelas de apresentação -----------------------------------
ic_percentual <- fmt(100 * nivel_confianca, 0)
# Tabela enxuta com o essencial do teste.
tabela_teste <- data.frame(
  Indicador = c(
    "Método",
    "Diferença de médias (A menos B)",
    paste0("IC ", ic_percentual, "% da diferença"),
    "t",
    "Graus de liberdade",
    "p-valor",
    "d de Cohen (tamanho do efeito)"
  ),
  Valor = c(
    metodo_teste,
    paste0(fmt(diferenca_medias), " mg/dia"),
    paste0("[", fmt(ic_diferenca[1]), "; ", fmt(ic_diferenca[2]), "]"),
    fmt(unname(teste_t$statistic)),
    fmt(unname(teste_t$parameter)),
    formatar_p(teste_t$p.value),
    paste0(fmt(d_cohen), " (", classe_efeito, ")")
  ),
  check.names = FALSE
)
# Tabela dos pressupostos, com leitura honesta linha a linha.
leitura_variancia <- if (variancias_iguais) "Sem evidência de variâncias diferentes." else "Há evidência de variâncias diferentes."
tabela_pressupostos <- data.frame(
  Teste = c("Shapiro-Wilk (ração A)", "Shapiro-Wilk (ração B)", "Teste F (variâncias)"),
  `p-valor` = formatar_p(c(p_shapiro_A, p_shapiro_B, p_variancia)),
  Leitura = c(
    if (p_shapiro_A >= alfa) "Sem evidência de desvio da normalidade." else "Evidência de desvio da normalidade.",
    if (p_shapiro_B >= alfa) "Sem evidência de desvio da normalidade." else "Evidência de desvio da normalidade.",
    leitura_variancia
  ),
  check.names = FALSE
)

# 8. Construir os gráficos -------------------------------------------------
# 8.1 Boxplot com os pontos de cada aquário: mostra dispersão e sobreposição.
# outlier.shape = NA evita desenhar o outlier duas vezes; os pontos vêm do jitter.
grafico_caixa <- ggplot(dados, aes(x = racao, y = .data[[variavel_resposta]], fill = racao)) +
  geom_boxplot(width = 0.5, alpha = 0.65, outlier.shape = NA) +
  geom_jitter(width = 0.12, size = 2, colour = "grey15", alpha = 0.8) +
  scale_fill_manual(values = cores_grupo) +
  labs(x = rotulo_grupo, y = rotulo_resposta, fill = rotulo_grupo) +
  tema_projeto() +
  theme(legend.position = "none")

# 8.2 Médias com intervalo de confiança de 95% por grupo.
# qt() dá o t crítico de cada grupo a partir dos seus graus de liberdade (n - 1).
resumo_ic <- tabela_descritiva |>
  mutate(
    t_critico = qt(1 - alfa / 2, df = n - 1),
    ic_baixo = media - t_critico * ep,
    ic_alto = media + t_critico * ep
  )
grafico_medias <- ggplot(resumo_ic, aes(x = racao, y = media, colour = racao)) +
  geom_errorbar(aes(ymin = ic_baixo, ymax = ic_alto), width = 0.15, linewidth = 0.8) +
  geom_point(size = 3) +
  scale_colour_manual(values = cores_grupo) +
  labs(
    x = rotulo_grupo,
    y = paste0("Média de ", rotulo_resposta),
    subtitle = paste0("Barras: intervalo de confiança de ", ic_percentual, "% da média")
  ) +
  tema_projeto() +
  theme(legend.position = "none")

# 9. Preparar os textos dos relatórios -------------------------------------
# Qual ração teve a maior média? Comparação direta entre os dois valores.
racao_maior <- if (media_A > media_B) rotulos_niveis[["A"]] else rotulos_niveis[["B"]]
# A evidência compara o p do teste com alfa, sem exagerar a conclusão.
evidencia <- if (teste_t$p.value < alfa) {
  "houve diferença significativa entre as médias das duas rações"
} else "não houve diferença significativa entre as médias das duas rações"

# Frases de pressupostos escritas conforme o resultado real de cada teste.
frase_normalidade <- if (normalidade_ok) {
  "não houve evidência contra a normalidade dentro dos grupos"
} else "houve evidência de afastamento da normalidade em pelo menos um grupo"
frase_variancia <- if (variancias_iguais) {
  "não houve evidência de variâncias diferentes"
} else "houve evidência de variâncias diferentes"

texto_amostra <- stringr::str_glue(
  "Foram analisados {n_total} aquários, {n_A} com a ração A (farelo de arroz) e ",
  "{n_B} com a ração B (farelo de babaçu), em delineamento inteiramente ",
  "casualizado, com uma réplica por aquário."
)

texto_pressupostos <- stringr::str_glue(
  "Quanto aos pressupostos, {frase_normalidade} ",
  "(Shapiro-Wilk: {formatar_p(p_shapiro_A, no_texto = TRUE)} para A e ",
  "{formatar_p(p_shapiro_B, no_texto = TRUE)} para B) e {frase_variancia} ",
  "(teste F: {formatar_p(p_variancia, no_texto = TRUE)}). ",
  "Um p acima de {fmt(alfa, 2)} não prova o pressuposto; apenas não dá ",
  "evidência para rejeitá-lo."
)

texto_resultado <- stringr::str_glue(
  "Pelo {metodo_teste}, {evidencia} ",
  "(t = {fmt(unname(teste_t$statistic))}; gl = {fmt(unname(teste_t$parameter))}; ",
  "{formatar_p(teste_t$p.value, no_texto = TRUE)}). ",
  "A ração A cresceu, em média, {fmt(media_A)} mg/dia e a ração B, {fmt(media_B)} mg/dia; ",
  "a diferença foi de {fmt(diferenca_medias)} mg/dia ",
  "(IC {ic_percentual}% [{fmt(ic_diferenca[1])}; {fmt(ic_diferenca[2])}])."
)

texto_efeito <- stringr::str_glue(
  "O tamanho do efeito foi {classe_efeito} (d de Cohen = {fmt(d_cohen)}). ",
  "A significância diz que a diferença existe; o d diz o quanto ela importa. ",
  "O rótulo é uma referência estatística, não uma leitura biológica direta."
)

texto_sintese <- stringr::str_glue(
  "No experimento com {n_total} aquários, {evidencia}. A maior taxa média de ",
  "crescimento foi da ração {racao_maior}, com diferença de {fmt(diferenca_medias)} mg/dia ",
  "(IC {ic_percentual}% [{fmt(ic_diferenca[1])}; {fmt(ic_diferenca[2])}]; ",
  "{formatar_p(teste_t$p.value, no_texto = TRUE)}) e tamanho de efeito {classe_efeito} ",
  "(d = {fmt(d_cohen)})."
)

# Comparação honesta: o que muda se usarmos Welch em vez de Student?
texto_welch <- stringr::str_glue(
  "Como referência, o t de Welch (que não assume variâncias iguais) dá ",
  "t = {fmt(unname(teste_welch$statistic))}; gl = {fmt(unname(teste_welch$parameter))}; ",
  "{formatar_p(teste_welch$p.value, no_texto = TRUE)}. Quando a igualdade de ",
  "variâncias é duvidosa, o Welch é a escolha segura."
)

# Impressões para conferência ao estudar o script (não entram nos relatórios).
print(texto_amostra)
print(texto_pressupostos)
print(texto_resultado)
print(texto_efeito)
print(texto_sintese)
print(texto_welch)

# 10. Salvar cópias para consulta ------------------------------------------
# CSV com ponto e vírgula e vírgula decimal abre bem no Excel em português.
write.csv2(dados, here::here("dados", "processados", "base_artemia.csv"),
           row.names = FALSE, fileEncoding = "UTF-8")
tabelas <- list(
  descritiva = tabela_descritiva,
  teste = tabela_teste,
  pressupostos = tabela_pressupostos
)
for (nome in names(tabelas)) {
  write.csv2(tabelas[[nome]], here::here("saida", "tabelas", paste0(nome, ".csv")),
             row.names = FALSE, fileEncoding = "UTF-8")
}
figuras <- list(caixa = grafico_caixa, medias = grafico_medias)
for (nome in names(figuras)) {
  ggsave(here::here("saida", "figuras", paste0(nome, ".png")),
         plot = figuras[[nome]], width = 7, height = 4.6, dpi = 300, bg = "white")
}

# 11. Registrar o ambiente computacional -----------------------------------
versao_quarto <- if (nzchar(Sys.which("quarto"))) {
  system2("quarto", "--version", stdout = TRUE)
} else "Quarto não encontrado no PATH desta sessão."
registro_ambiente <- c(paste("Quarto:", versao_quarto), capture.output(sessionInfo()))
writeLines(registro_ambiente, here::here("saida", "sessionInfo.txt"), useBytes = TRUE)
