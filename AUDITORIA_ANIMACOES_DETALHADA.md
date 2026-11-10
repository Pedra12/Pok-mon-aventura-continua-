# Auditoria detalhada das animações GLB

## Resultado da execução

- Workflow: [run 42915781046](https://github.com/Pedra12/Pok-mon-aventura-continua-/actions/runs/42915781046)
- Resultado: sucesso.
- Godot: 4.4.1.
- Modelos GLB examinados: 17/17.
- Clipes examinados: 29.
- Clipes com mudança de pose de ossos detectada: 26.
- Clipes com transformação de nós 3D detectada durante a amostragem: 22.
- Falhas de carregamento: nenhuma.
- Amostragem: 0%, 25%, 50%, 75% e 99% da duração de cada clipe.

O relatório bruto `animation_detail_report.json` está no artefato `validacao-importacao-godot` do workflow acima.

## Como interpretar

Esta é uma auditoria estrutural e temporal executada no Godot: os clipes foram reproduzidos por amostragem e as poses dos ossos e transformações dos nós foram comparadas com a pose inicial. Isso comprova que há movimento nos elementos identificados, mas **não comprova por si só que a animação é visualmente correta, que o personagem anda sem deslizar, que os pés tocam o chão ou que o movimento corresponde ao nome do clipe**. A aprovação visual ainda exige reprodução em cena e inspeção.

## Pokémon: resultado por modelo

| Modelo | Rig no Godot | Clipes e movimento detectado | Próxima decisão |
|---|---:|---|---|
| Amoonguss | 16 ossos | `idle` (2,46 s): 13 ossos mudam | Preservar como idle; mapear deformações de chapéu, corpo e braços antes de criar ações |
| Beedrill | 41 ossos | `Take 001` (5,00 s): 22 ossos e 7 nós mudam | Clipe ativo, mas função desconhecida; reproduzir e classificar antes de reutilizar |
| Diancie | 72 ossos | `mixamo.com` (39,60 s): 23 ossos e 19 nós mudam | Clipe ativo e longo; verificar orientação, root motion e compatibilidade com a anatomia |
| Eevee | Sem Skeleton3D | Nenhum clipe | Precisa de rig quadrúpede e pesos de skin antes de animação esquelética |
| Flygon | 94 ossos no Godot | 16 clipes; entre 51 e 61 ossos mudam por clipe | Melhor cobertura atual: há clipes separados com nomes associados a espera, caminhada, corrida, dano, queda e pouso; validar visualmente cada um |
| Hisuian Voltorb | 4 ossos | `Animation` (2,88 s): 1 osso muda | Clipe ativo, mas corpo esférico pede também movimento/rotação de raiz; verificar se o osso Chest é apenas detalhe |
| Ho-Oh | 165 ossos | `Take 001` (2,46 s): 80 ossos mudam | Clipe ativo; função desconhecida até inspeção visual. Não presumir que seja voo |
| Lucario | Sem Skeleton3D | Nenhum clipe | Precisa de rig bípede e pesos de skin |
| Magnemite | 5 ossos | `Idle` (3,29 s): 2 ossos e 17 nós mudam | Movimento detectado nos dois ímãs e em nós; manter abordagem de flutuação/peças, sem rig de pernas |
| Mew | Sem Skeleton3D | Nenhum clipe | Precisa de rig leve, cauda longa e pesos de skin |
| Celebi | 59 ossos | `ArmatureAction_001` (6,50 s): 46 ossos mudam | Clipe ativo; identificar visualmente a sequência antes de atribuir função |
| Shiny Metagross | Sem Skeleton3D | `Animation` (5,00 s): 20 nós mudam | Animação por peças/nós já existente; preservar, sem fabricar Skeleton3D |
| Smoliv | 4 ossos | `ArmatureAction` (2,79 s): 3 ossos mudam; dois clipes de controlador mudam 11 e 1 nós | Preservar os três clipes; avaliar em cena como uma única sequência ou ações separadas |
| Squirtle | 50 ossos no Godot | `Idle_01` (4,40 s): 18 ossos; `Idle_02` (7,27 s): 19 ossos | Duas variantes de idle detectadas; ainda faltam caminhada, corrida e ataques |

## Modelos auxiliares

- `original_pokemon_village.glb`: mapa, sem clipes de animação; preservado.
- `pokemon_basic_pokeball.glb`: acessório, sem Skeleton3D.
- `pokemon_sudowoodo_-_tree.glb`: modelo de árvore, sem Skeleton3D.

## Prioridade técnica recomendada

1. **Flygon:** testar primeiro os clipes existentes de espera, caminhada, corrida, dano, queda e pouso. É o único modelo com cobertura de muitos estados nomeados e 16 clipes já presentes. Os nomes são pistas, não aprovação visual.
2. **Squirtle:** comparar as duas variantes de idle e testar transições sem salto de pose.
3. **Amoonguss, Beedrill, Diancie, Voltorb, Ho-Oh, Magnemite, Celebi e Smoliv:** inspecionar visualmente os clipes existentes e identificar o que cada um faz antes de criar duplicatas.
4. **Metagross:** testar sua animação por nós e construir as ações ausentes usando a hierarquia de peças existente.
5. **Eevee, Lucario e Mew:** etapa separada de rigging/skin weights. Não aplicar animações de outros Pokémon nem inventar pesos automaticamente sem validar a deformação.

## Limitações e proteção dos assets

- Os cinco pontos amostrados podem não capturar movimentos muito rápidos que ocorram entre amostras.
- A contagem de ossos que mudaram não mede qualidade da deformação nem identifica sozinha a finalidade do movimento.
- Transformações de nós são reportadas separadamente de poses de ossos; elas podem ser parte legítima da animação de peças/controladores.
- Nenhum GLB original foi editado por esta auditoria.
- O mapa original e os perfis de escala aprovados permanecem preservados.
- Não foram criados clipes novos nesta etapa: primeiro estamos classificando o que já existe, para evitar substituir conteúdo útil ou criar animações incompatíveis.
