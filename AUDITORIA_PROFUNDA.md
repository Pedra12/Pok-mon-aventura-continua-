# Auditoria profunda do repositório (10/11/2026)

## Escopo verificado
Consulta à árvore Git recursiva da branch `main` (`git/trees/main?recursive=1`). O GitHub retornou `truncated=false`: árvore completa, sem truncamento.

## Resultado da árvore
- **19 itens no total**: 2 documentos Markdown + 17 arquivos GLB.
- **Nenhuma pasta/subpasta**.
- **Nenhum arquivo compactado** encontrado (ZIP, RAR, 7Z, TAR etc.).
- Nenhum arquivo de projeto Godot/Unity, script, áudio, vídeo, textura avulsa ou arquivo de animação separado.
- Os recursos 3D estão todos diretamente na raiz.

## Inventário completo (17 GLB)
| Arquivo | Tamanho (bytes) | Observação baseada no nome |
|---|---:|---|
| amoonguss.glb | 164.172 | Modelo Pokémon |
| beedrill.glb | 8.365.880 | Modelo Pokémon |
| diancie_dancing_to_sweet_dreams.glb | 1.478.444 | **Candidato a animação de dança**, confirmar clip interno |
| eevee_pokemon.glb | 1.263.992 | Modelo Pokémon |
| flygon_go_fest_2021.glb | 4.163.980 | Modelo Pokémon |
| hisuian_voltorb.glb | 8.554.368 | Modelo Pokémon |
| ho_oh.glb | 2.073.604 | Modelo Pokémon |
| lucario.glb | 2.484.300 | Modelo Pokémon |
| magnemite.glb | 446.748 | Modelo Pokémon |
| mew_pokemon.glb | 6.873.212 | Modelo Pokémon |
| original_pokemon_village.glb | 23.675.404 | **Cenário/mapa 3D** |
| pokemon_3ds_celebi.glb | 677.588 | Modelo Pokémon |
| pokemon_basic_pokeball.glb | 13.054.248 | Modelo de Pokébola |
| pokemon_sudowoodo_-_tree.glb | 1.354.152 | Árvore/objeto de cenário |
| shiny_metagross.glb | 1.234.044 | Modelo Pokémon |
| smoliv_fully_rigged.glb | 1.746.280 | **Indicado como rigged** pelo nome; rig não prova clips de animação |
| squirtle.glb | 2.373.100 | Modelo Pokémon |

## Tamanho total
79.983.724 bytes (aprox. 76,3 MiB).

## Animações: conclusão técnica
- **Possível animação incorporada:** `diancie_dancing_to_sweet_dreams.glb`, nome sugere dança, mas isso não comprova que o GLB contenha um AnimationClip.
- **Rig/esqueleto indicado:** `smoliv_fully_rigged.glb`; pode ser animável/retargetável, mas não há confirmação de clips embutidos.
- **Demais 15 GLBs:** não é possível afirmar animação ou ausência dela apenas pelo nome.
- O endpoint da árvore Git fornece nomes/tamanhos/SHA, não o conteúdo binário interno. O conector GitHub disponível não entrega binários GLB para inspeção de cabeçalho JSON; portanto, **não foi possível enumerar AnimationClips, duração, armature/bones ou testar playback dos 17 modelos nesta auditoria**. Não declarar como “sem animação” sem abrir os binários num leitor GLB.

## Próxima verificação necessária (binária)
Para concluir de verdade a auditoria de animações, é necessário baixar os GLBs e ler o JSON interno (glTF: `animations[]`, `skins[]`, nodes/bones) ou abrir cada um num visualizador GLB. O teste deve registrar: quantidade e nome dos clips, duração, skeleton/skin, materiais/texturas, escala/orientação e se o playback funciona.

## Documentos relacionados
- [README](README.md)
- [Auditoria inicial de assets](AUDITORIA_ASSETS.md)
