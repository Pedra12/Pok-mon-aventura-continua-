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
