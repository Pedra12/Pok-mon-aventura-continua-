# Auditoria detalhada das animações GLB

> **Documento histórico.** Esta auditoria foi produzida antes da retirada de Eevee, Lucario e Mew do conjunto ativo e antes da inclusão do perfil de escala do asset `pokemon_sudowoodo_-_tree.glb`. Os dados abaixo descrevem o inventário da execução histórica indicada. Para o inventário e os resultados atuais, consulte [STATUS_ATUAL_MODELOS.md](STATUS_ATUAL_MODELOS.md).

## Resultado da execução histórica

- Workflow: [run 42915781046](https://github.com/Pedra12/Pok-mon-aventura-continua-/actions/runs/42915781046)
- Resultado: sucesso.
- Godot: 4.4.1.
- Modelos GLB examinados: 17/17.
- Clipes examinados: 29.
- Clipes com mudança de pose de ossos detectada: 26.
- Clipes com transformação de nós 3D detectada durante a amostragem: 22.
- Falhas de carregamento: nenhuma.
- Amostragem: 0%, 25%, 50%, 75% e 99% da duração de cada clipe.

O relatório bruto `animation_detail_report.json` está no artefato `validacao-importacao-godot` da execução histórica acima.

## Como interpretar

Esta é uma auditoria estrutural e temporal executada no Godot: os clipes foram reproduzidos por amostragem e as poses dos ossos e transformações dos nós foram comparadas com a pose inicial. Isso comprova que há movimento nos elementos identificados, mas **não comprova por si só que a animação é visualmente correta, que o personagem anda sem deslizar, que os pés tocam o chão ou que o movimento corresponde ao nome do clipe**. A aprovação visual ainda exige reprodução em cena e inspeção.

## Pokémon: resultado por modelo na auditoria histórica

| Modelo | Rig no Godot | Clipes e movimento detectado | Próxima decisão registrada |
|---|---:|---|---|
| Amoonguss | 16 ossos | `idle` (2,46 s): 13 ossos mudam | Preservar como idle; mapear deformações de chapéu, corpo e braços antes de criar ações |
| Beedrill | 41 ossos | `Take 001` (5,00 s): 22 ossos e 7 nós mudam | Clipe ativo, mas função desconhecida; reproduzir e classificar antes de reutilizar |
| Diancie | 72 ossos | `mixamo.com` (39,60 s): 23 ossos e 19 nós mudam | Clipe ativo e longo; verificar orientação, root motion e compatibilidade com a anatomia |
| Flygon | 94 ossos no Godot | 16 clipes; entre 51 e 61 ossos mudam por clipe | Melhor cobertura atual de estados nomeados; validar visualmente cada um |
| Hisuian Voltorb | 4 ossos | `Animation` (2,88 s): 1 osso muda | Clipe ativo; corpo esférico pede também movimento/rotação de raiz |
| Ho-Oh | 165 ossos | `Take 001` (2,46 s): 80 ossos mudam | Clipe ativo; função desconhecida até inspeção visual |
| Magnemite | 5 ossos | `Idle` (3,29 s): 2 ossos e 17 nós mudam | Movimento detectado nos ímãs e em nós; abordagem de flutuação/peças |
| Celebi | 59 ossos | `ArmatureAction_001` (6,50 s): 46 ossos mudam | Clipe ativo; identificar visualmente a sequência |
| Shiny Metagross | Sem Skeleton3D | `Animation` (5,00 s): 20 nós mudam | Animação por peças/nós já existente; preservar sem fabricar Skeleton3D |
| Smoliv | 4 ossos | `ArmatureAction`: 3 ossos; dois clipes de controlador mudam 11 e 1 nós | Preservar os três clipes; avaliar em cena como ações separadas ou sequência |
| Squirtle | 50 ossos no Godot | `Idle_01`: 18 ossos; `Idle_02`: 19 ossos | Comparar variantes de idle e testar transições |

## Modelos arquivados ou auxiliares

- Eevee, Lucario e Mew aparecem nesta auditoria histórica, mas foram posteriormente retirados do conjunto ativo e preservados em `archive/deferred_models/`.
- `original_pokemon_village.glb`: mapa, sem clipes de animação; preservado.
- `pokemon_basic_pokeball.glb`: acessório, sem Skeleton3D.
- `pokemon_sudowoodo_-_tree.glb`: asset estático adicional, sem Skeleton3D e sem clipes. O nome indica uma árvore; não presumir que seja o Pokémon Sudowoodo nem atribuir-lhe animações de criatura sem inspeção visual.

## Prioridade técnica recomendada

1. **Flygon:** testar visualmente os clipes existentes de espera, caminhada, corrida, dano, queda e pouso.
2. **Squirtle:** comparar as duas variantes de idle e testar transições sem salto de pose.
3. **Amoonguss, Beedrill, Diancie, Voltorb, Ho-Oh, Magnemite, Celebi e Smoliv:** inspecionar visualmente os clipes existentes antes de criar duplicatas.
4. **Metagross:** testar sua animação por nós e construir ações ausentes usando a hierarquia de peças existente.
5. **Eevee, Lucario e Mew:** permanecem fora do conjunto ativo; eventual rigging deve ser uma etapa separada, com pesos de skin validados.

## Limitações e proteção dos assets

- Os cinco pontos amostrados podem não capturar movimentos muito rápidos que ocorram entre amostras.
- A contagem de ossos que mudaram não mede qualidade da deformação nem identifica sozinha a finalidade do movimento.
- Transformações de nós são reportadas separadamente de poses de ossos; podem ser parte legítima da animação de peças/controladores.
- Nenhum GLB original foi editado por esta auditoria.
- O mapa original e os perfis de escala permanecem preservados.
- Nenhum clipe novo foi criado nesta auditoria: primeiro é necessário classificar visualmente o conteúdo existente.
