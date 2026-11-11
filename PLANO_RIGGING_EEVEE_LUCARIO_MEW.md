# Plano técnico de rigging: Eevee, Lucario e Mew

## Estado da validação

Auditoria executada no commit `9b8c11f323a41251800c84daf820ee7e6c86713f`, com Godot 4.4.1. O workflow `42931880907` terminou com sucesso.

- 17/17 arquivos GLB importados.
- 16/16 modelos do laboratório carregados.
- 29 clipes iniciados, sem erros de reprodução.
- 14/14 perfis de escala aprovados.
- Mapa original preservado e carregado.
- Auditoria de geometria sem erros.

Esses resultados validam importação, execução e topologia numérica. Não comprovam deformação visual, qualidade artística nem adequação de cada clipe a uma ação específica.

## Resultados de conectividade

A auditoria considera componentes conectados por índices de triângulos em cada superfície. Os totais abaixo são componentes por superfície; peças duplicadas entre superfícies/materials podem aparecer separadamente. Portanto, componente desconectado não equivale automaticamente a uma articulação ou parte anatômica.

| Modelo | MeshInstances | Componentes encontrados | Vértices analisados | Triângulos |
|---|---:|---:|---:|---:|
| Eevee | 4 | 94 | 14.676 | 19.638 |
| Lucario | 10 | 185 | 35.807 | 63.606 |
| Mew | 1 | 57 | 5.029 | 7.750 |

### Eevee

- Quatro MeshInstances e 94 componentes de conectividade.
- As peças estão distribuídas por coordenadas de origem incomuns no arquivo importado.
- A quantidade de ilhas permite investigar separação de partes rígidas, mas não autoriza associar automaticamente cada ilha a orelha, cauda, cabeça ou pata.
- Próximo passo: produzir uma visualização de diagnóstico com cores por componente, preservando transformações e materiais, para identificar partes anatômicas antes de criar pivôs.

### Lucario

- Dez MeshInstances e 185 componentes de conectividade.
- Os nós de malha não possuem pivôs anatômicos úteis; vários vértices usam coordenadas locais absolutas.
- Há componentes e grupos repetidos, inclusive em superfícies diferentes. Isso pode decorrer de materiais, duplicação ou separação de superfícies.
- Próximo passo: visualizar cada MeshInstance e seus componentes com cores distintas; então criar pivôs auxiliares nos centros anatômicos identificados, sem alterar a posição final do modelo. A animação rígida só será aceita para peças realmente separadas. Articulações que precisem de deformação contínua exigem rig/weights.

### Mew

- Uma MeshInstance, uma superfície triangular e 57 componentes desconectados.
- A malha não é um único bloco topologicamente contínuo, apesar de estar armazenada em um único MeshInstance.
- Os componentes maiores têm distribuição espacial compatível com a possibilidade de partes corporais separadas, mas os dados numéricos não identificam sua função.
- Próximo passo: gerar visualização colorida por componente e conferir a silhueta. Se os componentes representarem membros/cauda separados, preparar pivôs por peça. Se houver regiões que precisem dobrar continuamente, será necessário rig esquelético e pesos por vértice. Não usar rotação global do modelo como substituto de animação corporal.

## Critérios antes de implementar animações

1. Visualizar o modelo original e a identificação de componentes lado a lado.
2. Confirmar a função anatômica de cada componente com base na geometria, não apenas no centroide.
3. Verificar peças duplicadas, sobrepostas, superfícies de materiais e componentes minúsculos que possam ser detalhes.
4. Criar pivôs mantendo a pose e o AABB originais.
5. Testar uma pose de articulação por vez e comparar com o modelo de referência.
6. Só então produzir idle, caminhada/corrida, salto e ações específicas.
7. Executar teste automatizado de importação e playback, além de inspeção visual do resultado.

## Restrições

- Não modificar o GLB original nem o mapa original durante a fase de diagnóstico.
- Não assumir que todos os componentes desconectados são peças animáveis.
- Não criar animação girando o personagem inteiro para simular caminhada.
- Não afirmar que um rig está visualmente correto apenas porque o Godot reproduz uma faixa ou porque os pesos somam 1.
- Manter os perfis de escala aprovados até existir evidência visual de erro.

## Próxima entrega técnica

Um diagnóstico visual por componente para Eevee, Lucario e Mew, com legenda estável de cores/IDs e vistas frontal, lateral e superior. Esse material será a base para a identificação anatômica e para o rigging sem adivinhação.
