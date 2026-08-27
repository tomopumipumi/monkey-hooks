# MonkeyHooks

MonkeyHooksは、Garmin Connect IQ (Monkey C) アプリケーション開発向けの、状態管理とユーティリティを提供するライブラリです。

UIの状態管理、システムリソース（タイマーやGPS）の共有、および画面遷移などの処理を整理し、保守性を高める目的で設計されています。

---

## 基本設計

MonkeyHooksは、以下のパラダイムに基づいて設計されています。

1. **状態の一元管理:**
アプリ全体で共有される単一の `Store` を持ちます。状態はキーによって管理され、任意のコンポーネントからアクセスおよび更新が可能です。
2. **自動的な描画更新:**
状態が `set()` によって更新されると、変更を検知して自動的に `WatchUi.requestUpdate()` を呼び出し、依存するリスナーや計算プロパティを再評価します。
3. **型安全性とNullチェック:**
Monkey Cの特性に対し、`useNumber` や `useString` などの型専用コンテキストを提供します。`req()` メソッドを使用することで、値が存在することを前提とした安全なアクセス（null時は例外スロー）が可能です。
4. **オプトイン設計とリソース共有:**
必要な機能のみをプロジェクトに含めることができるモジュール構造（オプトイン設計）を採用しています。また、`SharedTimer` や `LocationHook` は、複数のコンポーネントから参照されても単一のシステムリソースを共有し、内部の弱い参照（WeakReference）によりメモリリークを防ぎます。

---

## アーキテクチャ

```mermaid
graph TD
    classDef store fill:#eeeeee,stroke:#9e9e9e,stroke-width:2px,color:#000
    classDef hooks fill:#eeeeee,stroke:#9e9e9e,stroke-width:2px,color:#000
    classDef sys fill:#eeeeee,stroke:#9e9e9e,stroke-width:2px,color:#000
    classDef view fill:#ffffff,stroke:#666666,stroke-width:2px,color:#000
    classDef comp fill:#ffffff,stroke:#666666,stroke-width:1px,color:#000
    classDef os fill:#f9f9f9,stroke:#cccccc,stroke-width:2px,color:#000

    subgraph "Garmin OS / Hardware"
        Sensors((GPS / Timer)):::os
        Storage[(Local Storage)]:::os
        Screen((Watch Screen)):::os
    end

    subgraph "MonkeyHooks Framework"
        SystemH["System Hooks<br/>(LocationHook, SharedTimer)"]:::sys
        Router[Data-Driven Router]:::sys
        Store[(Global Store)]:::store
        
        Hooks["Type-Safe Hooks<br/>(useNumber, useString...)"]:::hooks
        Computed[useComputed]:::hooks
    end

    subgraph "Application"
        Delegate[Behavior Delegate]:::view
        View[View]:::view
        Dumb[Components]:::comp
    end

    Sensors -->|単一リソース共有| SystemH
    Storage <-->|自動保存・復元| Hooks
    
    SystemH -->|Callback| View
    Delegate -->|"set() 状態更新"| Hooks
    Hooks -->|Write| Store
    
    Store -->|Read / 通知| Hooks
    Store -->|Read| Computed

    Hooks --->|"get() / req()"| View
    Computed --->|"req()"| View
    
    View -->|引数として渡す| Dumb
    Dumb -->|描画| Screen
    
    Store -.->|Route_ID 検知| Router
    Router -.->|push / switchTo| Screen

```

---

## インストール

MonkeyHooksは、Gitサブモジュールとして導入することを推奨します。

### 1. サブモジュールの追加

プロジェクトのルートディレクトリで以下のコマンドを実行し、ライブラリを追加します。

```bash
git submodule add https://github.com/tomopumipumi/monkey-hooks.git lib/monkey-hooks

```

### 2. `monkey.jungle` の設定

アプリケーションのルートにある `monkey.jungle` を編集し、コンパイル対象のソースパスに MonkeyHooks の `src` フォルダを追加します。

```jungle
project.manifest = manifest.xml

# 既存の source に加えて、サブモジュールの src フォルダを指定
base.sourcePath = source;lib/monkey-hooks/src

```

---

## 使用方法

### 1. 基本的な状態管理

型に応じたフック（`useNumber`, `useString`, `useBoolean` など）を使用して状態を初期化・更新します。

```monkeyc
class MyDelegate extends WatchUi.BehaviorDelegate {
    private var _counter = MonkeyHooks.useNumber(:counter);

    function onSelect() {
        // 状態を更新（自動で WatchUi.requestUpdate() がトリガーされる）
        _counter.set(_counter.req() + 1);
        return true;
    }
}

```

### 2. UIでの状態の購読と描画（プッシュ型キャッシュ）

**重要:** GarminデバイスのCPU制約上、毎フレーム実行される `onUpdate` の内部で `MonkeyHooks.use...` を呼び出すと、辞書検索のオーバーヘッドにより処理落ち（コマ落ち）が発生します。
**状態は `onShow` でクラス変数にキャッシュし、`watch` を用いて変更を監視する「プッシュ型アーキテクチャ」を採用してください。**

```monkeyc
import Toybox.WatchUi;
import Toybox.Graphics;

class MyView extends WatchUi.View {
    // 描画用のキャッシュ変数（最速でアクセス可能）
    private var _currentCount as Number = 0;

    function initialize() {
        View.initialize();
        MonkeyHooks.useNumber(:counter).init(0); // Storeの初期化
    }

    function onShow() {
        // 1. 初回表示時にStoreから最新値を取得してキャッシュ
        _currentCount = MonkeyHooks.useNumber(:counter).req();

        // 2. 状態が変わった時だけ発火するリスナーを登録（プッシュ型通知）
        MonkeyHooks.watch(self, :onCounterChanged, [:counter]);
    }

    function onHide() {
        // メモリリーク防止のため監視を解除
        MonkeyHooks.unwatch(self, :onCounterChanged);
    }

    // 値が変更された時だけ呼ばれ、キャッシュを最新化する
    function onCounterChanged(vals as Array) as Void {
        if (vals[0] != null) {
            _currentCount = vals[0] as Number;
        }
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        
        // onUpdate内ではMonkeyHooksを呼ばず、キャッシュ変数のみを使用する
        dc.drawText(100, 100, Graphics.FONT_LARGE, "Count: " + _currentCount, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

```

### 3. 計算プロパティ (useComputed)

他の状態に依存して計算される派生状態を作成します。依存する状態が変化したときのみ再計算が行われます。

```monkeyc
class BmiCalculator {
    function calcBmi(deps as Array) as Float {
        var w = deps[0].toFloat();
        var h = deps[1].toFloat() / 100.0;
        return (w / (h * h)).toFloat();
    }
}

var _bmiCalculator = new BmiCalculator();

class UserProfile {
    private var _weight = MonkeyHooks.useNumber(:weight).init(70);
    private var _height = MonkeyHooks.useNumber(:height).init(175);
    
    private var _bmi = MonkeyHooks.useComputed(
        :bmi,
        [:weight, :height],
        _bmiCalculator.method(:calcBmi)
    );

    function printBmi() {
        System.println("BMI: " + _bmi.req());
    }
}

```

### 4. コレクション型の操作と強制更新 (forceSet)

Monkey Cの仕様上、配列や辞書は参照比較（`!=`）が行われます。既存の配列の中身を変更して `set()` を呼び出しても、変更として検知されません。
要素を直接操作した場合は、参照比較をスキップして強制的に更新をトリガーする `forceSet()` を使用してください。

```monkeyc
var arrHook = MonkeyHooks.useArray(:myList);
var list = arrHook.req();

list.add("New Item"); // 配列の中身を変更（参照は同じ）

// arrHook.set(list); // 参照が同一のため無視される
arrHook.forceSet(list); // 強制的に更新通知と再描画を実行

```

### 5. 永続化ストレージ (useStorageString)

`Application.Storage` と連携し、アプリ終了後も保持される状態を作成します。

```monkeyc
var userName = MonkeyHooks.useStorageString("username").init("Guest");
userName.set("Bob"); // Storeの更新と Storage.setValue() が同時に実行される

```

*(※ ストレージフックを `onUpdate` や高頻度のタイマー内で読み書きしないでください。フラッシュメモリの寿命を縮め、パフォーマンスが致命的に低下します。)*

### 6. リソース共有 (SharedTimer / LocationHook)

システムリソースを安全に共有します。最初のリスナーが登録された時点でリソースが起動し、リスナーがゼロになると自動で停止します。

```monkeyc
class MainView extends WatchUi.View {
    function onShow() {
        MonkeyHooks.SharedTimer.subscribe(self, :onTick);
        MonkeyHooks.LocationHook.subscribe(self, :onLocationUpdated);
    }

    function onTick() as Void { /* 一定間隔の処理 */ }
    function onLocationUpdated(info as Position.Info) as Void { /* GPS処理 */ }

    function onHide() {
        MonkeyHooks.SharedTimer.unsubscribe(self, :onTick);
        MonkeyHooks.LocationHook.unsubscribe(self, :onLocationUpdated);
    }
}

```

### 7. ルーティング (MonkeyRouter)

ViewとDelegateの生成を管理し、画面遷移を行います。

```monkeyc
function onStart(state) {
    MonkeyHooks.Router.initialize(method(:viewFactory));
}

function viewFactory(routeId as Number) as Array? {
    switch(routeId) {
        case 1: return [new HomeView(), new HomeDelegate()];
        case 2: return [new SettingsView(), null];
    }
    return null;
}

// 遷移の実行
MonkeyHooks.Router.push(1, WatchUi.SLIDE_LEFT);

```

---

## 🚨 ベストプラクティス：パフォーマンスを極めるために

Garminデバイスでのアニメーションや描画を滑らかに保つため、以下のルールを遵守してください。

### 1. `onUpdate` 内からのMonkeyHooks排除

`WatchUi.View.onUpdate()` は秒間十数回呼ばれる過酷なループです。この中で `useNumber` や `Store.get` を呼び出すと、ハッシュ検索のオーバーヘッドにより描画が重くなります。
必ず **`onLayout` や `onShow` のタイミングでクラス内変数にキャッシュ** し、`onUpdate` ではそのローカル変数を読み取るだけにしてください。

### 2. 使い捨ての描画バッファにはHookを使わない

ポリゴンの座標計算など、描画時に一瞬だけ使う配列バッファを `MH.usePolygonBuffer` 等で管理すると検索コストがかかります。
1つのコンポーネント内だけで完結する一時的な計算バッファは、**モジュールのプライベート静的変数**などを用いて使い回すのが最速です。

### 3. 子コンポーネントへの「配列パッキング」

UIコンポーネントを別ファイルに切り出す際、子コンポーネント内でHookを呼ぶとパフォーマンスが低下します。親（View）で取得した画面サイズやフォントなどの静的データは、1つの配列にまとめて（配列パッキング）引数としてバケツリレーで渡す手法が、Monkey Cにおいて最も高速です。

```monkeyc
// 親Viewの onLayout でキャッシュを作成
_layoutCtx = [displayWidth, titleFont, valueFont];

// onUpdate で子コンポーネントにまとめて渡す
MyComponent.render(dc, _layoutCtx);

```

## ライセンス

MIT License
Copyright (c) 2026 Ichimura Tomoo
