# Estado atual dos modelos 3D

**Atualizado:** 11/11/2026  
**Branch:** `main`  
**Commit de validação:** `d5e29615f7038cef865ae4a2da907cd63d9135c4`  
**Workflow:** [Validação Godot 4.4.1, execução 42935138011](https://github.com/Pedra12/Pok-mon-aventura-continua-/actions/runs/42935138011)

## Inventário ativo

A raiz contém **14 arquivos GLB**:

- **12 Pokémon ativos:** Amoonguss, Beedrill, Diancie, Flygon, Voltorb de Hisui, Ho-Oh, Magnemite, Celebi, Sudowoodo, Metagross shiny, Smoliv e Squirtle.
- **1 mapa:** `original_pokemon_village.glb`.
- **1 acessório:** `pokemon_basic_pokeball.glb`.

Eevee, Lucario e Mew foram retirados do conjunto ativo e preservados, sem alteração, em `archive/deferred_models/`. Eles não são carregados pelo laboratório nem incluídos no conjunto de validação atual.

## Resultado da validação mais recente

Todas as etapas do workflow passaram no Godot 4.4.1:

- 14/14 GLBs importados.
- 13/13 arquivos do conjunto de teste do laboratório carregados.
- 29 clipes reproduzidos sem erros.
- 26 clipes apresentaram mudanças de pose esquelética.
- 22 clipes apresentaram mudanças de transformação de nós.
- 11/11 perfis de escala passaram na validação anterior. O perfil de Sudowoodo foi acrescentado depois e está aguardando a nova execução automática do workflow; portanto, ainda não conto esse novo perfil como aprovado.
- O mapa foi preservado e carregado.
- A análise do mapa encontrou 58 superfícies de malha e 55 candidatas geometricamente horizontais.

**Interpretação importante:** esses resultados confirmam importação, estrutura, reprodução técnica e consistência numérica de escala. Não comprovam que as animações estejam visualmente corretas, que os movimentos correspondam ao nome dos clipes, nem que o mapa já tenha colisores de gameplay ou pontos de spawn seguros.

O Sudowoodo agora tem perfil individual calculado para 1,2 m, usando os limites medidos no Godot. O novo perfil ainda precisa passar pela execução automática antes de ser considerado validado.\n\n## Próxima prioridade: Flygon

O Flygon tem 16 clipes e é o melhor candidato para iniciar a classificação visual. O relatório detectou movimento em dezenas de ossos em cada clipe. Durações e nomes importados:

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

Os nomes são apenas pistas. Nenhum desses clipes deve receber uma função definitiva de gameplay sem inspeção visual. Preservar os clipes originais.

## Limites desta etapa

- O repositório contém os assets 3D e ferramentas de validação; esta execução **não gerou APK**.
- A análise geométrica do mapa não identifica semanticamente chão, telhado, mesa ou plataforma.
- A validação de escala usa limites geométricos e perfis; não substitui avaliação visual de proporções e pivôs.
- Nenhum GLB original ou o mapa foi editado nesta etapa.

## Relatórios

O artefato `validacao-importacao-godot` da execução indicada acima contém os relatórios JSON de importação, animações, playback, escalas e superfícies do mapa.
