# FS25 Loose Cargo

**FS25 Loose Cargo** to skryptowy mod do Farming Simulator 25, który symuluje gubienie nieprzykrytego ładunku sypkiego podczas szybkiej jazdy.

Mod działa automatycznie dla standardowych przyczep, naczep i wozów przeładunkowych. Nie wymaga modyfikowania plików XML poszczególnych maszyn.

## Założenia

Mod został zaprojektowany według następujących zasad:

- działa dla kategorii `TRAILERS`, `TRAILERSSEMI` i `AUGERWAGONS`;
- dotyczy materiałów sypkich należących do kategorii `BULK` oraz kompatybilnych niestandardowych `fillType` oznaczonych jako `isBulkType`;
- obejmuje m.in. ziarno, rośliny okopowe, zrębki, trawę, siano, słomę, sieczkę, kiszonkę, pasze, nasiona, nawóz stały, wapno, sól drogową, kamienie i obornik;
- ubytek występuje tylko podczas jazdy z prędkością większą niż ustalony próg;
- zamknięta pokrywa całkowicie zatrzymuje gubienie ładunku, jeżeli dana skrzynia posiada pokrywę;
- pojazd bez pokrywy jest traktowany jako stale odkryty;
- im większa prędkość, tym większy ubytek;
- lżejsze materiały są tracone szybciej niż cięższe;
- wraz ze zmniejszaniem poziomu napełnienia straty maleją;
- przy napełnieniu równym 25% lub mniejszym materiał nie jest już tracony;
- mod działa tylko dla pojazdów kierowanych przez gracza;
- pracownik AI nie powoduje strat; przejęcie pojazdu przez gracza ponownie uruchamia mechanizm;
- podczas normalnego rozładunku nie jest naliczana dodatkowa strata.

## Sposób działania

### Prędkość

Domyślny próg wynosi:

```lua
FS25LooseCargo.MIN_SPEED_KMH = 25.0
```

Do 25 km/h włącznie ładunek nie jest tracony. Powyżej tej wartości współczynnik strat rośnie kwadratowo wraz z prędkością.

Punktem odniesienia jest 50 km/h:

```lua
FS25LooseCargo.REFERENCE_SPEED_KMH = 50.0
FS25LooseCargo.BASE_LOSS_PER_MINUTE = 0.01
```

Dla materiału o gęstości zbliżonej do pszenicy i przyczepy wypełnionej w 100% odpowiada to około 1% aktualnego ładunku na minutę przy 50 km/h.

### Gęstość materiału

Mod korzysta z `massPerLiter` przypisanego do danego `fillType` przez grę. Współczynnik jest liczony względem pszenicy:

```text
sqrt(gęstość pszenicy / gęstość materiału)
```

Dzięki temu lekkie materiały, takie jak słoma i siano, są tracone szybciej, natomiast cięższe materiały, np. wapno lub kamienie, wolniej.

Dla bezpieczeństwa współczynnik jest ograniczony do zakresu:

```lua
FS25LooseCargo.MIN_DENSITY_FACTOR = 0.50
FS25LooseCargo.MAX_DENSITY_FACTOR = 2.50
```

### Stopień napełnienia

Przy niskim poziomie napełnienia materiał znajduje się głębiej wewnątrz skrzyni, dlatego jest mniej narażony na działanie pędu powietrza.

Domyślnie:

```lua
FS25LooseCargo.MIN_EXPOSED_FILL_PERCENT = 0.25
```

Poniżej tego poziomu straty nie występują. Pomiędzy 25% a 100% współczynnik ekspozycji rośnie liniowo.

| Napełnienie | Współczynnik ekspozycji |
|---:|---:|
| 25% lub mniej | 0.00 |
| 40% | 0.20 |
| 50% | 0.33 |
| 75% | 0.67 |
| 100% | 1.00 |

### Pokrywa

Jeżeli dany `fillUnit` posiada przypisaną pokrywę, mod sprawdza jej stan. Zamknięta pokrywa całkowicie wyłącza straty niezależnie od prędkości, gęstości materiału i stopnia napełnienia.

Jeżeli pojazd nie ma pokrywy, ładunek jest traktowany jako odkryty.

## Tabela działania

Poniższe wartości przedstawiają orientacyjną stratę **aktualnego ładunku na minutę** dla materiału o gęstości zbliżonej do pszenicy, przy odkrytej i całkowicie wypełnionej przyczepie.

| Prędkość | Strata / min |
|---:|---:|
| 25 km/h | 0.00% |
| 30 km/h | 0.04% |
| 40 km/h | 0.36% |
| 50 km/h | 1.00% |
| 60 km/h | 1.96% |
| 75 km/h | 4.00% |
| 90 km/h | 6.76% |
| 100 km/h | 9.00% |

Do powyższej wartości stosowany jest następnie współczynnik gęstości materiału oraz współczynnik ekspozycji zależny od poziomu napełnienia.

Przykład dla pszenicy przy 50 km/h:

| Napełnienie | Orientacyjna strata / min |
|---:|---:|
| 25% | 0.00% |
| 50% | 0.33% |
| 75% | 0.67% |
| 100% | 1.00% |

Maksymalna strata jest ograniczona przez:

```lua
FS25LooseCargo.MAX_LOSS_PER_MINUTE = 0.12
```

czyli do 12% aktualnego ładunku na minutę przed uwzględnieniem współczynnika ekspozycji.

## Konfiguracja

Najważniejsze parametry znajdują się na początku pliku `LooseCargo.lua`:

```lua
FS25LooseCargo.MIN_SPEED_KMH = 25.0
FS25LooseCargo.REFERENCE_SPEED_KMH = 50.0
FS25LooseCargo.BASE_LOSS_PER_MINUTE = 0.01
FS25LooseCargo.MAX_LOSS_PER_MINUTE = 0.12
FS25LooseCargo.MIN_EXPOSED_FILL_PERCENT = 0.25
FS25LooseCargo.MIN_DENSITY_FACTOR = 0.50
FS25LooseCargo.MAX_DENSITY_FACTOR = 2.50
FS25LooseCargo.UPDATE_INTERVAL_MS = 1000
```

Znaczenie parametrów:

- `MIN_SPEED_KMH` — minimalna prędkość, powyżej której mogą wystąpić straty;
- `REFERENCE_SPEED_KMH` — prędkość odniesienia dla `BASE_LOSS_PER_MINUTE`;
- `BASE_LOSS_PER_MINUTE` — bazowa strata aktualnego ładunku na minutę przy prędkości odniesienia;
- `MAX_LOSS_PER_MINUTE` — ograniczenie maksymalnej intensywności strat;
- `MIN_EXPOSED_FILL_PERCENT` — poziom napełnienia, poniżej którego straty nie występują;
- `MIN_DENSITY_FACTOR` / `MAX_DENSITY_FACTOR` — ograniczenia wpływu gęstości materiału;
- `UPDATE_INTERVAL_MS` — odstęp pomiędzy obliczeniami strat.

Zmiana `BASE_LOSS_PER_MINUTE` z `0.01` na `0.02` podwoi bazową intensywność strat. Wartość `0.005` zmniejszy ją o połowę.

## Obsługiwane pojazdy

Mod monitoruje pojazdy należące do kategorii:

- `TRAILERS` — przyczepy;
- `TRAILERSSEMI` — naczepy;
- `AUGERWAGONS` — wozy przeładunkowe.

Podczas testów potwierdzono poprawne działanie zwykłych przyczep, naczep oraz wozów przeładunkowych, w tym prawidłową obsługę pokryw i pojazdów prowadzonych przez pracownika AI.

## Instalacja

1. Skopiuj plik `FS25_LooseCargo.zip` do katalogu:

   ```text
   Documents\My Games\FarmingSimulator2025\mods
   ```

2. Włącz mod przy ładowaniu zapisu gry.

Mod jest przeznaczony do gry jednoosobowej.

## Historia zmian

### 1.1.0.0

- pierwsza stabilna wersja przygotowana do normalnego użycia;
- uporządkowanie kodu i usunięcie diagnostycznych wpisów z logu;
- zachowanie sprawdzonej obsługi przyczep, naczep i wozów przeładunkowych;
- zachowanie wpływu prędkości, gęstości, pokrywy i stopnia napełnienia;
- dopracowanie `modDesc.xml` i dokumentacji.

### 1.0.5.0

- dodano współczynnik ekspozycji zależny od stopnia napełnienia;
- brak strat przy poziomie 25% lub niższym;
- intensywność strat rośnie liniowo od 25% do 100% napełnienia.

### 1.0.4.0

- poprawiono obsługę materiałów mogących występować również jako palety lub bele;
- ziemniaki, buraki, marchew, pasternak, zrębki, kiszonka, trawa, siano, słoma, sieczka i TMR są prawidłowo traktowane jako ładunek sypki w przyczepie.

### 1.0.3.0

- zastosowano kategorię `BULK` do rozpoznawania materiałów sypkich;
- dodano diagnostykę `fillType` i `massPerLiter` na potrzeby testów.

### 1.0.2.0

- zmieniono sposób rozpoznawania pojazdów na kategorie sklepowe;
- dodano obsługę `TRAILERS`, `TRAILERSSEMI` i `AUGERWAGONS`.

### 1.0.1.0

- poprawiono moment wstrzykiwania specjalizacji przez `TypeManager.validateTypes`.

### 1.0.0.0

- pierwsza wersja prototypowa mechanizmu gubienia ładunku.

## Uwagi

Mod celowo nie dodaje efektu cząsteczkowego rozsypywania materiału. Uniwersalne wyznaczenie miejsca emisji dla wszystkich modeli przyczep i wozów przeładunkowych wymagałoby dodatkowych założeń dotyczących ich geometrii. Obecna wersja pozostaje dzięki temu lekka i niezależna od konkretnych modeli maszyn.
