# Estado atual dos modelos 3D

**Atualizado:** 11/11/2026  
**Branch:** `main`  
**Commit com perfil de escala de Sudowoodo/árvore:** `84634bd86f0012e088a6186245c44efb868093c6`  
**Workflow validado:** [Godot 4.4.1, execução 42935813214](https://github.com/Pedra12/Pok-mon-aventura-continua-/actions/runs/42935813214)

## Inventário ativo

A raiz contém **14 arquivos GLB**:

- **11 modelos de Pokémon identificados como criaturas:** Amoonguss, Beedrill, Diancie, Flygon, Voltorb de Hisui, Ho-Oh, Magnemite, Celebi, Metagross shiny, Smoliv e Squirtle.
- **1 modelo estático adicional:** `pokemon_sudowoodo_-_tree.glb`. O arquivo não tem esqueleto nem clipes; seu nome indica uma árvore. Embora o perfil de escala tenha sido calculado usando 1,20 m, não há confirmação visual suficiente para afirmar que seja o Pokémon Sudowoodo. Não atribuir animações de criatura a esse asset sem inspeção.
- **1 mapa:** `original_pokemon_village.glb`.
- **1 acessório:** `pokemon_basic_pokeball.glb`.

Eevee, Lucario e Mew foram retirados do conjunto ativo e preservados, sem alteração, em `archive/deferred_models/`.

## Resultado da validação mais recente

Todas as etapas do workflow passaram no Godot 4.4.1:

- 14/14 arquivos GLB importados.
- 13/13 arquivos do laboratório carregados (11 modelos de Pokémon, o modelo estático adicional e a Poké Bola).
- 29 clipes reproduzidos sem erros.
- 26 clipes apresentaram mudanças de pose esquelética.
- 22 clipes apresentaram mudanças de transformação de nós.
- 12/12 perfis de escala passaram, incluindo o perfil do modelo `pokemon_sudowoodo_-_tree.glb`.
- 12/12 instâncias reais passaram na validação de escala e posicionamento.
- O mapa foi preservado e carregado.
- A análise geométrica do mapa encontrou 58 superfícies de malha e 55 candidatas geometricamente horizontais.

**Interpretação importante:** os resultados confirmam importação, estrutura, reprodução técnica e consistência numérica de escala. Não comprovam que as animações estejam visualmente corretas, que os movimentos correspondam ao nome dos clipes, nem que o mapa já tenha colisores de gameplay ou pontos de spawn seguros.

## Próxima prioridade: classificação visual do Flygon

O Flygon tem 16 clipes existentes. Os nomes e durações são pistas, não aprovação visual:

| Clipe | Duração |
|---|---:|
| ba01_land01 | 0,68 s |
| ba10_waitA01 | 1,48 s |
| ba10_waitB01 | 1,76 s |
| ba20_buturi01 | 1,88 s |
| ba21_tokusyu01 | 2,36 s |
| ba30_damageS01 | 0,68 s |
| ba41_down01 | 1,68 s |
| fi01_wait01 | 1,48 s |
| fi20_walk01 | 1,48 s |
| fi21_run01 | 1,00 s |
| kw01_wait01 | 2,12 s |
| kw30_hate01 | 2,00 s |
| kw32_happyB01 | 1,68 s |
| kw50_eatA01 | 0,20 s |
| kw50_eatB01 | 0,40 s |
| kw50_eatC01 | 0,68 s |

A auditoria estrutural detectou movimento em dezenas de ossos por clipe. Ainda falta renderizar e inspecionar visualmente orientação, contato com o chão, deformações, clipping e continuidade dos loops. Preservar todos os clipes originais; não atribuir estados definitivos de gameplay apenas pelo nome.

## Limites desta etapa

- O repositório contém assets 3D e ferramentas de validação; a execução 42935813214 **não gerou APK**.
- A análise geométrica do mapa não identifica semanticamente chão, telhado, mesa ou plataforma.
- A validação de escala usa limites geométricos e perfis; não substitui avaliação visual de proporções e pivôs.
- Nenhum GLB original nem o mapa foi editado nesta etapa.

## Relatórios

O artefato `validacao-importacao-godot` da [execução 42935813214](https://github.com/Pedra12/Pok-mon-aventura-continua-/actions/runs/42935813214) contém os relatórios JSON de importação, animações, playback, escalas, instâncias e superfícies do mapa.
