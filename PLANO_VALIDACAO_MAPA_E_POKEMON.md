# Proxima etapa: validacao do mapa e padronizacao dos modelos

## Mapa original_pokemon_village.glb
- Preservar o arquivo original, sem reexportar ou substituir o GLB.
- Medir limites X/Y/Z, centro geometrico, origem, hierarquia de nos, malhas, materiais e quantidade estimada de vertices.
- Inspecionar objetos individuais para localizar terreno, construcoes, entradas, interiores e possiveis obstaculos.
- Validar no Godot a orientacao dos eixos, escala importada, colisao do terreno e pontos livres para spawn.

## Pokemon
- Ler dimensoes individuais, centro, transforms, hierarquia e nomes dos ossos.
- Mapear cada canal de animacao para o no/ osso que ele realmente controla.
- Preservar os clipes existentes e testar sua reproducao no Godot.
- Criar rig e animacoes apenas para modelos sem rig/clipes, com articulacoes adequadas a cada especie.

## Padronizacao conjunta
- Definir uma unidade de referencia no mapa e uma altura-alvo por especie.
- Calcular escala individual por modelo, sem aplicar fator global.
- Corrigir pivô/origem e orientacao sem alterar os arquivos fonte.
- Gerar cenas de teste com personagem, camera, terreno e colisores.

## Criterios de aprovacao
1. O mapa inteiro pode ser explorado sem ficar preso em geometria ou nascer dentro de objetos.
2. Personagens mantêm proporcoes coerentes com portas, casas, arvores e terreno.
3. Caminhada, corrida, espera, ataque e dano reproduzem corretamente quando houver clipes adequados.
4. Nenhum GLB original e sobrescrito; todas as transformacoes ficam em cenas/configuracoes do projeto.

Esta etapa e um plano de validacao. Nenhuma escala final ou animacao e considerada aprovada antes do teste de importacao e reproducao no Godot.
