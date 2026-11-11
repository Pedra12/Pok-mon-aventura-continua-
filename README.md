# Pokémon Aventura Continua

Repositório de assets 3D e ferramentas de validação para o RPG Pokémon 3D.

## Estado atual

- [Status atual dos modelos ativos e validação Godot](STATUS_ATUAL_MODELOS.md)
- [Auditoria detalhada de animações](AUDITORIA_ANIMACOES_DETALHADA.md)
- [Avaliação técnica de rigging e skinning](AVALIACAO_RIGGING_POKEMON.md)

## Assets na raiz

- 11 modelos de Pokémon identificados como criaturas.
- 1 modelo estático adicional: `pokemon_sudowoodo_-_tree.glb`. O nome do arquivo sugere uma árvore; não deve ser tratado como modelo de Sudowoodo animável sem confirmação visual.
- Mapa: `original_pokemon_village.glb`.
- Acessório: `pokemon_basic_pokeball.glb`.
- Eevee, Lucario e Mew preservados em `archive/deferred_models/`, fora do conjunto ativo.

Total: 14 arquivos GLB na raiz.

## Histórico de auditorias

- [Auditoria profunda inicial](AUDITORIA_PROFUNDA.md)
- [Inventário inicial dos assets](AUDITORIA_ASSETS.md)

Os documentos de inventário inicial registram estados anteriores à reorganização. Para números e resultados atuais, consulte sempre o [status atual](STATUS_ATUAL_MODELOS.md).

**Nota:** a validação de importação/animação não significa que o jogo esteja completo nem que exista um APK gerado.
