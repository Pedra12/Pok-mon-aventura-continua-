# Resultado da primeira auditoria dos modelos 3D

**Execucao:** GitHub Actions, workflow `Analisar modelos 3D GLB`  
**Resultado:** sucesso  
**Arquivos GLB examinados:** 17  
**Relatorio bruto:** artefato `auditoria-modelos-3d` da execucao 42877138542.

## Resumo

- 11 modelos de Pokémon declaram pelo menos um clipe de animação no GLB.
- 3 modelos de Pokémon não declaram clipes nem esqueleto: Eevee, Lucario e Mew.
- Metagross declara um clipe de animação, mas não possui skin/esqueleto glTF. A animação pode ser de nós/objetos, não uma animação esquelética do corpo.
- O mapa, a Pokébola e o modelo de árvore também foram analisados, mas não são Pokémon animáveis como personagens.

## Pokémon com animações declaradas

| Modelo | Esqueletos / ossos | Clipes detectados |
|---|---:|---:|
| Amoonguss | 1 / 16 | 1 (idle) |
| Beedrill | 1 / 41 | 1 (Take 001) |
| Diancie | 1 / 72 | 1 (mixamo.com) |
| Flygon | 1 / 92 | 16 |
| Hisuian Voltorb | 1 / 4 | 1 (Animation) |
| Ho-Oh | 1 / 165 | 1 (Take 001) |
| Magnemite | 1 / 5 | 1 (Idle) |
| Celebi | 1 / 59 | 1 (ArmatureAction.001) |
| Metagross | 0 / 0 | 1 (Animation; sem skin glTF) |
| Smoliv | 1 / 4 | 3 |
| Squirtle | 1 / 49 | 2 |

### Flygon

Os nomes dos 16 clipes incluem:
- `ba01_land01`
- `ba10_waitA01`, `ba10_waitB01`
- `ba20_buturi01`, `ba21_tokusyu01`
- `ba30_damageS01`, `ba41_down01`
- `fi01_wait01`, `fi20_walk01`, `fi21_run01`
- `kw01_wait01`, `kw30_hate01`, `kw32_happyB01`
- `kw50_eatA01`, `kw50_eatB01`, `kw50_eatC01`

Os nomes foram lidos dos metadados do GLB. É necessário reproduzir os clipes no Godot para confirmar visualmente o movimento e mapear cada um para o estado correto do jogo.

## Pokémon sem esqueleto e sem clipes

| Modelo | Dimensões X × Y × Z reportadas |
|---|---:|
| Eevee | 190.741 × 141.360 × 156.391 |
| Lucario | 2.964 × 1.877 × 2.964 |
| Mew | 65.247 × 60.032 × 41.409 |

Esses três exigem preparação de rig/animação. Antes de criar os ossos, será necessário inspecionar a malha e definir articulações adequadas à anatomia de cada espécie.

## Dimensões e escala: alerta importante

O analisador calculou caixas envolventes da geometria importada. As medidas são unidades originais do arquivo, não necessariamente metros nem escala comum entre arquivos.

Há diferenças muito grandes entre os valores:
- Eevee, Beedrill e Ho-Oh aparecem com dimensões muito maiores que outros modelos.
- Hisuian Voltorb aparece com dimensões próximas de 0,02 unidade.
- Alguns modelos têm centro geométrico deslocado da origem.

Portanto, **não aplicar uma escala global igual a todos**. O próximo passo deve padronizar unidades, origem/pivô, orientação e escala de cada modelo no Godot, preservando as proporções.

## Próximas etapas técnicas

1. Melhorar o relatório para calcular a duração dos clipes a partir dos tempos dos samplers glTF.
2. Importar os modelos no Godot e validar escala, orientação, pivô e animações visualmente.
3. Criar um AnimationTree/AnimationPlayer por espécie com nomes de estados consistentes.
4. Criar rigs próprios para Eevee, Lucario e Mew, sem alterar os GLBs originais.
5. Produzir movimentos ausentes somente depois de confirmar a hierarquia e a deformação das malhas.

## Limites desta auditoria

Esta primeira execução confirmou a presença de arrays de animação, skins, nós, malhas e caixas envolventes. Ela ainda não confirmou que todos os clipes são reproduzíveis, que a animação movimenta o corpo inteiro, nem que a escala reportada está pronta para uso no jogo. Isso exige validação de importação e reprodução no Godot.


## Segunda passagem: duração e tipo de canais das animações

O analisador foi ampliado para ler os intervalos de tempo dos samplers e classificar os canais glTF. A segunda execução também terminou com sucesso.

| Modelo | Clipe(s) e duração calculada |
|---|---|
| Amoonguss | idle: 2,458 s |
| Beedrill | Take 001: 4,933 s |
| Diancie | mixamo.com: 39,600 s |
| Flygon | 16 clipes entre 0,200 s e 2,360 s |
| Hisuian Voltorb | Animation: 2,875 s |
| Ho-Oh | Take 001: 2,458 s |
| Magnemite | Idle: 3,292 s |
| Celebi | ArmatureAction.001: 6,500 s |
| Metagross | Animation: 4,958 s |
| Smoliv | 3 clipes: 2,792 s; 2,042 s; 2,042 s |
| Squirtle | Idle_01: 4,000 s; Idle_02: 2,467 s |

### Flygon: clipes úteis já identificados

- Caminhada: `fi20_walk01` (1,480 s).
- Corrida: `fi21_run01` (1,000 s).
- Espera: `fi01_wait01` (1,480 s), além de outras variações.
- Dano: `ba30_damageS01` (0,680 s).
- Queda: `ba41_down01` (1,680 s).
- Pouso: `ba01_land01` (0,680 s).

### Cuidado na interpretação

A duração é calculada pelo maior e menor tempo declarado nos accessors de entrada dos samplers. Isso confirma a faixa temporal armazenada, mas não prova que a animação seja um ciclo contínuo, que esteja visualmente correta ou que corresponda ao nome sugerido. A validação final será feita reproduzindo cada clipe no Godot.

O relatório detalhado atualizado está disponível no artefato da execução [42883950187](https://github.com/Pedra12/Pok-mon-aventura-continua-/actions/runs/42883950187).


## Terceira passagem: estrutura detalhada do mapa

**Execucao:** [42884883514](https://github.com/Pedra12/Pok-mon-aventura-continua-/actions/runs/42884883514)  
**Resultado:** sucesso

O arquivo `original_pokemon_village.glb` foi analisado separadamente, incluindo a hierarquia dos nós e os limites transformados das malhas.

| Propriedade | Resultado |
|---|---:|
| Nós na cena | 60 |
| Malhas | 58 |
| Vértices de posição estimados | 333.672 |
| Materiais | 28 |
| Texturas / imagens | 26 |
| Dimensões X × Y × Z | 354,140 × 20,632 × 110,698 |
| Limite mínimo X/Y/Z | -56,347 / -2,000 / -39,929 |
| Limite máximo X/Y/Z | 297,793 / 18,632 / 70,770 |

### Consequência para o posicionamento no jogo

O centro da caixa envolvente do mapa fica aproximadamente em **X=120,723; Y=8,316; Z=15,420**, portanto não está na origem (0,0,0). Não devemos colocar o personagem no ponto zero supondo que ali seja o centro ou um local livre. O ponto inicial precisa ser escolhido após visualizar o cenário e verificar colisões.

### Organização interna

A cena tem um nó raiz e um nó agrupador que contém 58 malhas. Os nomes das malhas são genéricos (`Object_2` até `Object_59`), sem rótulos que permitam identificar com segurança casas, ruas, árvores ou interiores apenas pelo nome.

Os limites individuais mostram que várias malhas ocupam grandes regiões e outras são estreitas/alongadas. Isso sugere que o cenário foi exportado em partes, mas não permite afirmar qual objeto visual cada malha representa sem abrir o modelo no visualizador 3D.

### Limites desta etapa

- As dimensões foram calculadas pelos limites dos vértices transformados pela hierarquia glTF.
- A auditoria não encontrou nem criou colisores físicos.
- Não confirmou se portas e interiores são acessíveis, nem se existem paredes invisíveis.
- Não definiu escala em metros nem ponto de spawn.
- O GLB original não foi modificado.

O relatório estruturado completo, incluindo os 60 nós, as 58 malhas e seus limites individuais, está no artefato `auditoria-modelos-3d` da execução acima.


## Quarta passagem: importação real no Godot 4.4.1

**Execução:** [42885381978](https://github.com/Pedra12/Pok-mon-aventura-continua-/actions/runs/42885381978)  
**Resultado:** sucesso

Os 17 arquivos GLB foram importados como cenas pelo Godot 4.4.1 em modo headless e instanciados por um verificador. Não houve falha de carregamento.

| Verificação | Resultado |
|---|---:|
| Arquivos testados | 17 |
| Arquivos carregados | 17 |
| Falhas | 0 |
| Instâncias de malha | 131 |
| Nós Skeleton3D | 10 |
| Clipes encontrados pelo Godot | 29 |

### Confirmação do mapa

O Godot importou `original_pokemon_village.glb` sem erro e encontrou **58 MeshInstance3D** distribuídos em 61 nós da cena. Isso confirma que o cenário pode ser carregado como uma cena Godot, mas ainda não valida colisões, acessibilidade ou navegação.

### Confirmação dos Pokémon

- Eevee, Lucario e Mew carregam, mas não apresentam Skeleton3D nem AnimationPlayer.
- Flygon carrega com 16 clipes e um Skeleton3D com 94 ossos na cena importada.
- Squirtle carrega com 2 clipes e 50 ossos na cena importada.
- Metagross carrega com AnimationPlayer e um clipe, mas sem Skeleton3D; deve ser testado como animação de nós/peças.
- Os demais modelos com animações também carregaram e expuseram seus AnimationPlayers.

### Diferenças de nomes no importador

O Godot normalizou alguns nomes de clipes para identificadores compatíveis, por exemplo `mixamo.com` tornou-se `mixamo_com`, e `ArmatureAction.001` tornou-se `ArmatureAction_001`. Flygon e Smoliv mantêm nomes compostos com separadores. O jogo deverá consultar os nomes efetivamente importados pelo Godot, não presumir que são idênticos aos nomes brutos do glTF.

### O que ainda não foi validado

Esta execução confirma carregamento e presença de malhas/esqueletos/clipes. O verificador ainda não reproduziu os clipes nem mediu caixas envolventes após importação. Também não criou colisores ou cenas de gameplay. A próxima etapa será gerar cenas de inspeção e reproduzir os clipes em sequência para conferir visualmente a deformação, orientação, pivô e escala.
