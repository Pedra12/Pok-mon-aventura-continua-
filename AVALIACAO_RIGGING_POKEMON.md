# Avaliação de preparação para rigging

Base: relatório Godot da execução [42915781046](https://github.com/Pedra12/Pok-mon-aventura-continua-/actions/runs/42915781046). Esta avaliação usa a estrutura importada, quantidade de nós e MeshInstances, e presença/ausência de Skeleton3D. Não é uma inspeção visual dos pesos nem substitui teste de deformação.

| Pokémon | Nós na cena | MeshInstances | Skeleton3D | Preparação técnica |
|---|---:|---:|---:|---|
| Eevee | 12 | 4 | 0 | Não está pronto para animação esquelética. Há quatro malhas separadas, o que pode permitir rig híbrido, mas nomes genéricos e a distribuição real das peças precisam ser inspecionados visualmente. Para deformação contínua de tronco, pescoço e pernas, será necessário criar armature e skin weights. |
| Lucario | 13 | 10 | 0 | Não está pronto para animação esquelética. A divisão em dez malhas sugere possibilidade de articulação rígida por peças em algumas partes, mas não prova que braços, pernas, mãos e cabeça estejam separados corretamente ou com pivôs úteis. Requer inspeção e provavelmente rig híbrido com pesos. |
| Mew | 4 | 1 | 0 | Não está pronto. O corpo é uma malha única, portanto movimentos naturais de braços, pernas, tronco e cauda exigem armature e skin weights. É o caso de maior trabalho de skinning entre os três. |
| Shiny Metagross | 25 | 14 | 0 | Não precisa de Skeleton3D para aproveitar o clipe já existente: a animação altera 20 nós. A estratégia correta é preservar a animação por peças e validar pivôs/limites. |
| Magnemite | 24 | 8 | 1 | Já tem esqueleto pequeno e animação; os dois ímãs mudam de pose. Também existem nós de peças que se movimentam. |
| Smoliv | 18 | 6 | 1 | Já tem esqueleto de quatro ossos e controladores de nós. Preservar os três clipes e testar as relações entre controlador e armature. |

## Decisões para os três modelos sem esqueleto

### Eevee
- Não aplicar rig bípede.
- Construir uma hierarquia quadrúpede: raiz, quadril, coluna, peito, pescoço, cabeça, quatro cadeias de patas, orelhas e cauda.
- Antes de pesar vértices, confirmar se as quatro MeshInstances representam partes anatômicas independentes ou malhas sobrepostas/auxiliares.
- Validar flexão de ombros, quadris, joelhos, pescoço e base da cauda.

### Lucario
- Construir uma hierarquia bípede: raiz, quadril, coluna, peito, pescoço, cabeça, clavículas, braços, antebraços, mãos, coxas, pernas, pés e cauda.
- Inspecionar as dez MeshInstances e seus pivôs. Se partes anatômicas já estiverem separadas, usar articulação rígida onde não houver deformação; usar skin weights nas junções que precisem dobrar.
- Validar postura neutra, passada, corrida, golpe e agachamento sem separação de malhas.

### Mew
- Criar rig leve e flexível, com coluna, pescoço/cabeça, membros curtos e cauda longa segmentada.
- Como há apenas uma MeshInstance, preparar skin weights por regiões anatômicas; não mover vértices por grupos rígidos como solução final.
- Validar flutuação, inclinação do tronco, gesto dos braços, curvas da cauda e esquiva.

## Portão de qualidade antes de integrar

Nenhum desses três modelos deve receber animações de gameplay até passar por:
1. rig com nomes e hierarquia estáveis;
2. skin weights sem vértices soltos ou influências abruptas;
3. pose neutra alinhada ao perfil de escala aprovado;
4. teste de deformação nos extremos de cada articulação;
5. exportação GLB e reimportação no Godot;
6. validação visual em cena com câmera, chão e escala de referência.

Não altere o mapa, os GLBs originais nem os perfis de escala para compensar problemas de rigging. Trabalhar em cópias derivadas versionadas dos modelos.


## Auditoria objetiva de skinning (execução 42919177031)

Relatório gerado pelo Godot 4.4.1 em [42919177031](https://github.com/Pedra12/Pok-mon-aventura-continua-/actions/runs/42919177031), com inspeção de `ARRAY_BONES`, `ARRAY_WEIGHTS` e vértices por superfície. Os pesos foram analisados numericamente; isso comprova vínculo técnico, mas não comprova deformação visual perfeita.

| Modelo | Malhas com skin | Vértices examinados | Vértices sem peso | Máx. influências ativas/vértice | Resultado |
|---|---:|---:|---:|---:|---|
| Amoonguss | 1 | 602 | 0 | 2 | Skin válido numericamente |
| Beedrill | 2 | 6.550 | 0 | 2 | Skin válido numericamente |
| Diancie | 6 | 6.213 | 0 | 4 | Skin válido numericamente |
| Flygon | 3 | 4.216 | 0 | 4 | Skin válido numericamente |
| Hisuian Voltorb | 2 | 1.748 | 0 | 1 | Skin válido; influência rígida |
| Ho-Oh | 4 | 21.569 | 0 | 4 | Skin válido numericamente |
| Magnemite | 2 | 616 | 0 | 1 | Skin válido; influência rígida |
| Celebi | 5 | 2.711 | 0 | 3 | Skin válido numericamente |
| Smoliv | 6 | 21.485 | 0 | 1 | Skin válido; influência rígida |
| Squirtle | 4 | 3.136 | 0 | 4 | Skin válido numericamente |
| Eevee | 0 | 0 | — | — | Sem Skeleton3D/skin |
| Lucario | 0 | 0 | — | — | Sem Skeleton3D/skin |
| Mew | 0 | 0 | — | — | Sem Skeleton3D/skin |

Em todas as superfícies listadas com skin, a soma mínima e máxima dos pesos por vértice ficou aproximadamente entre 0,99994 e 1,00000 (ou exatamente 1,0 nos modelos com influência única). Nenhum vértice foi classificado como sem peso. Isso é um bom sinal para a integridade dos dados de skinning, mas não substitui inspeção visual de articulações, orientações dos ossos e deformações em poses extremas.

O relatório detalhado encontrou **29 clipes**, com **26 clipes apresentando mudança de pose esquelética** e **22 clipes apresentando movimento de nós** durante amostragem em cinco instantes (0%, 25%, 50%, 75% e 99%). Esses números descrevem movimento detectado, não a função semântica do clipe: nomes como idle/walk/run são pistas, mas cada animação ainda precisa ser visualmente conferida antes de ser atribuída a um estado de gameplay.

### Próximas prioridades técnicas

1. **Flygon:** começar pela inspeção visual dos 16 clipes já existentes e mapear quais servem a repouso, locomoção, voo, dano e reações. Não renomear nem atribuir funções finais sem assistir aos clipes.
2. **Squirtle:** comparar visualmente os dois clipes Idle e testar a deformação do corpo, membros e cauda.
3. **Amoonguss, Beedrill, Ho-Oh e Celebi:** validar os clipes existentes e criar estados ausentes aproveitando os rigs e pesos atuais.
4. **Magnemite e Smoliv:** usar movimentos por ossos/nós compatíveis com suas estruturas simples; evitar exigir articulações que os modelos não possuem.
5. **Eevee, Lucario e Mew:** criar rigs próprios em cópias derivadas; não aplicar clipes de outros Pokémon.
6. **Metagross:** preservar a animação por nós já existente e validar os pivôs das peças.

### Limite desta validação

O workflow importa e inspeciona os GLBs em modo headless. Não renderiza uma sessão visual de cada Pokémon nem certifica qualidade artística, clipping, contato dos pés com o chão ou naturalidade da animação. A próxima etapa precisa gerar cenas de teste/turntables e revisar cada clipe visualmente. O mapa original e os perfis de escala permanecem intocados.


## Smoke test de reprodução (execução 42923477986)

Workflow: [42923477986](https://github.com/Pedra12/Pok-mon-aventura-continua-/actions/runs/42923477986). Resultado do artefato `animation_playback_smoke_report.json`:

- **29 clipes testados** em 11 modelos com AnimationPlayer.
- **17 modelos GLB examinados**; 6 não possuem AnimationPlayer/clipes (Eevee, Lucario, Mew, mapa, Pokébola e Sudowoodo).
- **0 erros de reprodução registrados**; status geral `success`.
- Flygon teve os 16 clipes executados; Squirtle, os 2 idles; Smoliv, os 3 clipes; Metagross, o clipe por nós.

Esse teste confirma que os AnimationPlayers e seus clipes podem ser iniciados e avançados pelo Godot sem erro detectado. **Não confirma visualmente** se a animação está bonita, se o Pokémon anda na direção correta, se há clipping ou se o clipe corresponde ao estado de gameplay. Isso continua exigindo cenas renderizadas e revisão visual.

### Próximo passo implementável

Criar uma cena de laboratório de animação no Godot com seleção de Pokémon/clipe, reprodução/pausa, velocidade 0,25x/0,5x/1x e câmera ajustada ao perfil de escala. A cena deve usar os GLBs originais sem editá-los e carregar os perfis de escala existentes. Primeiro alvo: Flygon, por ter o maior conjunto de clipes; em seguida Squirtle. A aprovação será visual, não apenas baseada em logs.
