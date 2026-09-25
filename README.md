# Crescimento de Artemia — uma análise, dois documentos

Este exemplo aplica o teste *t* para duas amostras independentes ao conjunto
`EAPADados::artemia`. Abra **teste-t-artemia.Rproj** no RStudio. O projeto
funciona com a planilha local e pacotes do CRAN, sem depender da CatalyseR.

## A pergunta

Uma fábrica de ração afirma que o farelo de arroz (A) faz a *Artemia salina*
crescer mais rápido que o farelo de babaçu (B). O experimento é um
**delineamento inteiramente casualizado (DIC)** com dois tratamentos e
**7 réplicas por ração** (14 aquários independentes). A análise compara as
médias de crescimento e mede o tamanho da diferença.

## Um convite a aprender programação

Este projeto foi organizado para você acompanhar como uma análise funciona:
de onde vêm os dados, quais pressupostos são checados e como os resultados
chegam ao relatório. Os comentários do script explicam cada decisão; os nomes
dos objetos permitem examinar etapa por etapa. É um caminho do mouse ao código:
quem começa pela CatalyseR encontra aqui a chance de entender o que a ferramenta
faz e de modificar a análise com autonomia.

## O que você encontra

```text
teste-t-artemia/
├── teste-t-artemia.Rproj
├── _quarto.yml
├── dados/
│   ├── brutos/artemia.csv            # planilha original, somente leitura
│   └── processados/base_artemia.csv  # base usada na análise
├── R/
│   ├── analise.R                     # leia e altere os cálculos aqui
│   └── funcoes.R                     # números, tema e tabelas Ocean
├── imagens/                          # para fotos e esquemas fornecidos por você
├── relatorios/
│   ├── relatorio_completo.qmd        # caderno HTML, com exploração e pressupostos
│   ├── relatorio_artigo.qmd          # Word, com os resultados principais
│   ├── referencias.bib
│   ├── apa.csl                       # estilo de citação (troque se precisar)
│   ├── custom-reference.docx         # modelo Word usado no ecossistema
│   └── ocean.scss
└── saida/
    ├── tabelas/                      # CSV
    ├── figuras/                      # PNG em 300 dpi
    ├── relatorios/                   # HTML e Word
    └── sessionInfo.txt               # R, pacotes e Quarto da execução
```

O R calcula; os QMDs executam esse script e apresentam os objetos prontos.
Você não copia código entre arquivos. O Render de cada documento recalcula a
análise e recria as saídas. Os QMDs **não leem** os CSVs e PNGs de `saida/`:
usam os objetos criados na memória da execução.

| No script R | No relatório | Cópia salva para compartilhar |
|---|---|---|
| `tabela_teste` reúne o resultado do teste | `flextable_ocean(tabela_teste)` | `saida/tabelas/teste.csv` |
| `grafico_caixa` guarda a figura | `grafico_caixa` | `saida/figuras/caixa.png` |
| `texto_resultado` reúne números numa frase | Expressão R inline no parágrafo | A frase entra no HTML e no Word |

## Preparar o computador, uma vez

Instale R, RStudio e Quarto. No console do R, instale os pacotes:

```r
install.packages(c("here", "dplyr", "ggplot2", "stringr",
                   "flextable", "knitr", "rmarkdown"))
```

Nenhum pacote é instalado automaticamente durante a análise.

## Gerar os documentos

1. Abra o `.Rproj` e reinicie o R para começar com uma sessão limpa.
2. Abra `relatorios/relatorio_completo.qmd` e clique em **Render** para o HTML.
3. Abra `relatorios/relatorio_artigo.qmd` e clique em **Render** para o Word.

Para gerar os dois pelo terminal, na raiz do projeto: `quarto render`.
Para estudar só a análise, abra `R/analise.R` e execute as seções em ordem.

## Como a análise decide o método

O teste *t* clássico pede **normalidade dentro de cada grupo** e **variâncias
parecidas entre os grupos**. O script confere a normalidade com Shapiro-Wilk em
cada ração e a igualdade de variâncias com o **teste F**. Quando o teste F não
dá evidência de variâncias diferentes, usa-se o **t de Student**; quando dá, a
escolha segura é o **t de Welch**. O script guarda os dois resultados para você
comparar. As frases dos relatórios são escritas conforme o resultado real de
cada teste: um *p* acima de 0,05 não prova o pressuposto, apenas não dá
evidência para rejeitá-lo.

O tamanho do efeito é o **d de Cohen**, calculado à mão com o desvio padrão
combinado, com rótulos de referência (pequeno, médio, grande). A significância
diz que a diferença existe; o *d* diz o quanto ela importa.

## Como escrever e adaptar

Os dois QMDs trazem sugestões em Introdução, Material e métodos, Resultados,
Discussão e Conclusão. No HTML as dicas ficam visíveis; no artigo elas ficam em
comentários `<!-- ... -->` que não entram no Word. Para usar outros dados de
duas amostras, troque a planilha em `dados/brutos/`, ajuste os nomes das colunas
e os rótulos no início de `R/analise.R` e revise os trechos específicos dos
relatórios. O exemplo foi escrito para esta comparação, não é um gerador
genérico de análises.

## Origem dos dados

O conjunto vem de `EAPADados::artemia`: dados fictícios baseados em um problema
clássico de bioestatística, próprios para demonstrar o teste *t* de comparação
de médias. As colunas são `racao` (níveis A e B) e `taxa_crescimento_mg_dia`.
A cópia local em `dados/brutos/artemia.csv` usa ponto e vírgula e vírgula
decimal, no padrão do Excel em português.

O registro `saida/sessionInfo.txt` identifica o ambiente da execução. Ele ajuda
a conferir versões, mas não congela nem reinstala esse ambiente. A reprodução
futura depende de preservar dados, código e as decisões da versão usada.
