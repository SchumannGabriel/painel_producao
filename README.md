# Painel de Produção — Flutter + Firebase

Painel em tempo real de produção por setor, conectado à coleção `producao_ativa` do Firebase.

---

## Funcionalidades

- **KPIs no topo**: Meta do Dia e Produção do Dia, cada um com gráfico de rosca mostrando % da meta
- **Seletor de setores**: tabs dinâmicos buscados do Firebase, filtrados por hoje
- **Tabela por funcionário** com:
  - Nome do funcionário (com dot de status colorido)
  - Meta do dia
  - Produção acumulada em cada hora: 07h, 08h, 09h, 10h, 11h, 12h, 13h, 14h, 15h, 16h, 17h, 17:48
  - Total produzido
  - % da meta (badge colorido: verde ≥ 100%, azul ≥ 80%, amarelo ≥ 50%, vermelho < 50%)
- **Relógio em tempo real** no header
- **Badge "AO VIVO"** pulsante
- Coluna da hora atual destacada em azul
- Atualização automática via Firestore `snapshots()`

---

##  Instalação

### 1. Pré-requisitos
- Flutter SDK 3.x instalado
- Conta Firebase com projeto `registro-producao`
- FlutterFire CLI

### 2. Instalar FlutterFire CLI
```bash
dart pub global activate flutterfire_cli
```

### 3. Configurar Firebase
```bash
# Na raiz do projeto:
flutterfire configure --project=registro-producao
```
Isso vai sobrescrever `lib/firebase_options.dart` com suas credenciais reais.

### 4. Instalar dependências
```bash
flutter pub get
```

### 5. Rodar
```bash
# Web (recomendado para painel)
flutter run -d chrome

# Android
flutter run -d android

# Desktop (Windows/macOS/Linux)
flutter run -d windows  # ou macos / linux
```

---

##  Estrutura do Projeto

```
lib/
├── main.dart                        # Entry point + init Firebase
├── firebase_options.dart            #  Gerado pelo flutterfire configure
├── app_theme.dart                   # Design tokens (cores, tipografia)
├── models/
│   └── producao_model.dart          # ProducaoAtiva, Snapshot, ResumoSetor
├── services/
│   └── producao_service.dart        # Streams Firebase + lógica de agregação
├── screens/
│   └── painel_producao_screen.dart  # Tela principal
└── widgets/
    ├── donut_kpi_card.dart          # Card KPI com gráfico rosca
    ├── tabela_producao.dart         # Tabela horária por funcionário
    └── setor_tab_bar.dart           # Tabs de seleção de setor
```

---

##  Estrutura Firestore esperada

### Coleção: `producao_ativa`

```json
{
  "ordem": "OF-2024-001",
  "quantidade": 145,
  "meta": 200,
  "funcionario": "João Silva",
  "setor": "Costura",
  "status": "em andamento",
  "inicio": Timestamp,
  "atualizado_em": Timestamp,
  "finalizado_em": null,
  "snapshots": [
    {
      "periodo": "07:30",
      "quantidade": 25,
      "registrado_em": Timestamp
    },
    {
      "periodo": "09:00",
      "quantidade": 80,
      "registrado_em": Timestamp
    }
  ]
}
```

### Como os snapshots são lidos na tabela

Para cada coluna horária (ex: "09h" = `09:00`), o painel pega o snapshot com
período **≤ esse horário** mais próximo. Ou seja, se há um snapshot `09:30`
e a coluna é `09:00`, ele ainda não aparece — só aparece na coluna `10h`.

---

##  Cores de Status

| % da Meta | Cor |
|-----------|-----|
| ≥ 100% | 🟢 Verde |
| ≥ 80% | 🔵 Azul |
| ≥ 50% | 🟡 Amarelo |
| < 50% | 🔴 Vermelho |

---

##  Regras Firestore recomendadas

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /producao_ativa/{doc} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

---

##  Dependências

```yaml
firebase_core: ^2.24.2
cloud_firestore: ^4.14.0
intl: ^0.18.1
```
