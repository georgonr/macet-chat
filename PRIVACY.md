# Ochrana súkromia — Macet Secure Chat

Platné od 28. 7. 2026. Tento dokument popisuje, čo o vás vie aplikácia Macet Secure Chat a servery,
na ktoré sa pripája. Údaje v ňom zodpovedajú skutočnej konfigurácii serverov k uvedenému dátumu.

## Kto to prevádzkuje

Macet Secure Chat prevádzkuje súkromný subjekt (fyzická osoba alebo organizácia), nie obchodná
spoločnosť poskytujúca verejnú službu. Kontakt: **[DOPLNIT_KONTAKT]**

Aplikácia je fork projektu [SimpleX Chat](https://github.com/simplex-chat/simplex-chat), šírený pod
licenciou AGPLv3. Zdrojový kód tohto buildu je na
[github.com/georgonr/macet-chat](https://github.com/georgonr/macet-chat).

Servery bežia na vlastnej infraštruktúre prevádzkovateľa na doméne `cht.macet.eu`:

| služba | adresa | úloha |
|---|---|---|
| SMP | `cht.macet.eu:5223` | doručovanie správ |
| XFTP | `cht.macet.eu:5443` | prenos súborov a médií |
| TURN | `cht.macet.eu:3478` | prenos audio/video hovorov |

Fyzicky ide o jeden virtuálny server (Hetzner Online GmbH, Nemecko). Prevádzkovateľ má k nemu plný
administrátorský prístup.

## Čo je šifrované

Obsah správ, súborov a hovorov je šifrovaný end-to-end medzi zariadeniami účastníkov. Server vidí
len zašifrované dáta a **prevádzkovateľ servera ich nevie prečítať**. To platí aj pre názvy súborov,
profilové mená a obrázky, ktoré si vymieňate s kontaktmi.

## Čo server vidí

Šifrovanie obsahu neznamená neviditeľnosť. Server nutne vidí a môže zaznamenať:

- **IP adresu zariadenia**, ktoré sa pripája — teda približnú polohu a poskytovateľa pripojenia,
- **časy pripojení** a časy odovzdania jednotlivých správ,
- **objem prenesených dát**, veľkosť a počet správ a súborov,
- **súhrnnú dennú štatistiku** prevádzky (na SMP serveri je zapnutá, `log_stats = on`; na XFTP
  serveri je vypnutá).

TURN server pri hovoroch zapisuje spojenia vrátane IP adries do logu kontajnera.

Server nemá identifikátory používateľov — nepracuje s účtami, ale s anonymnými frontami správ.
Z IP adries a časov však možno odvodzovať vzory prevádzky. Kto to chce obmedziť, môže v aplikácii
zapnúť SOCKS proxy a smerovať prenos cez Tor (*Nastavenia → Sieť a servery → Use SOCKS proxy*).

## Ako dlho sa dáta uchovávajú

Servery neuchovávajú históriu správ. Správa sa zo servera zmaže hneď po doručení. Skutočné
nastavenie našich serverov:

- **nedoručené správy: 21 dní** (`expire_messages_days = 21`), potom sa zmažú,
- **notifikácie: 24 hodín** (`expire_ntfs_hours = 24`),
- **súbory a médiá: 48 hodín** (`expire_files_hours = 48`), potom sa zmažú bez ohľadu na to,
  či ich príjemca stihol stiahnuť,
- správy sú držané v pamäti (`store_messages = memory`); pri reštarte servera sa nedoručené správy
  obnovia zo zálohy (`restore_messages = on`),
- záznamy o frontách správ sa vedú v append-only logu, aby prežili reštart servera,
- neaktívne spojenia sa odpájajú po 6 hodinách (`ttl = 21600`).

História vašich konverzácií existuje len v zašifrovanej databáze vo vašom zariadení. Ak ju stratíte,
prevádzkovateľ vám ju nevie obnoviť.

## Čo aplikácia nezbiera

- Pri vytvorení profilu sa **nezadáva telefónne číslo, e-mail ani používateľské meno** na serveri.
  Meno profilu je len lokálny údaj, ktorý zdieľate s kontaktmi.
- Aplikácia **neobsahuje reklamy, analytiku, telemetriu ani hlásenie pádov**.
- Aplikácia sa nepripája na žiadne servery tretích strán. Desktopová verzia nemá ani kontrolu
  aktualizácií.

## Hovory a vaša IP adresa

Audio a video hovory idú cez TURN relay `cht.macet.eu:3478`. Relay vidí trvanie a objem hovoru,
nie jeho obsah.

Voľba **„Always use relay"** (*Nastavenia → Audio a video hovory*) je **zapnutá predvolene**. Ak ju
vypnete, hovor sa nadviaže priamo medzi zariadeniami a **druhá strana uvidí vašu IP adresu**.
Ak vám na tom záleží, nechajte voľbu zapnutú.

## Náhľady odkazov

Náhľady odkazov sú **predvolene zapnuté**. Keď ich necháte zapnuté, vaše zariadenie si stiahne obsah
odkazovanej stránky, a tá stránka tým uvidí vašu IP adresu. Vypnúť sa dajú v *Nastavenia → Súkromie
a bezpečnosť*.

## Hranice tohto dokumentu

Prevádzkovateľ má nad serverom plnú kontrolu a technicky mu nič nebráni zmeniť konfiguráciu alebo
software tak, aby zaznamenával viac, než je tu uvedené. Tento dokument je vyhlásenie o zámere, nie
technická záruka.

Skutočnou zárukou je end-to-end šifrovanie: aj keby server logoval všetko, čo mu prejde, obsah
správ z toho nezíska. Zdrojový kód aplikácie je verejný a dá sa z neho build overiť.

## Zmeny

Zmeny tohto dokumentu sú viditeľné v histórii commitov repozitára.

---

# Privacy policy — Macet Secure Chat

Effective 28 July 2026. This document describes what the Macet Secure Chat app and the servers it
connects to know about you. It reflects the actual server configuration as of that date.

## Who runs it

Macet Secure Chat is run by a private party (an individual or an organisation), not by a company
providing a public service. Contact: **[DOPLNIT_KONTAKT]**

The app is a fork of [SimpleX Chat](https://github.com/simplex-chat/simplex-chat), distributed under
the AGPLv3. The source of this build is at
[github.com/georgonr/macet-chat](https://github.com/georgonr/macet-chat).

The servers run on the operator's own infrastructure under the `cht.macet.eu` domain:

| service | address | role |
|---|---|---|
| SMP | `cht.macet.eu:5223` | message delivery |
| XFTP | `cht.macet.eu:5443` | file and media transfer |
| TURN | `cht.macet.eu:3478` | audio/video call relay |

Physically this is a single virtual server (Hetzner Online GmbH, Germany). The operator has full
administrative access to it.

## What is encrypted

The content of messages, files and calls is end-to-end encrypted between the participants' devices.
The server only ever sees encrypted data and **the server operator cannot read it**. This also covers
file names, profile names and images you exchange with your contacts.

## What the server sees

Encrypted content does not mean invisible. The server necessarily sees, and can record:

- the **IP address of the connecting device** — that is, your approximate location and your ISP,
- **connection times** and the times individual messages are handed over,
- the **volume of transferred data**, and the size and number of messages and files,
- **aggregate daily traffic statistics** (enabled on the SMP server, `log_stats = on`; disabled on
  the XFTP server).

During calls the TURN server writes connections, including IP addresses, to the container log.

The server holds no user identifiers — it works with anonymous message queues rather than accounts.
IP addresses and timing can still reveal traffic patterns. To limit that, you can enable the SOCKS
proxy in the app and route traffic over Tor (*Settings → Network & servers → Use SOCKS proxy*).

## How long data is kept

The servers keep no message history. A message is removed from the server as soon as it is
delivered. The actual settings of our servers are:

- **undelivered messages: 21 days** (`expire_messages_days = 21`), then they are deleted,
- **notifications: 24 hours** (`expire_ntfs_hours = 24`),
- **files and media: 48 hours** (`expire_files_hours = 48`), then they are deleted whether or not
  the recipient has downloaded them,
- messages are held in memory (`store_messages = memory`); on a server restart undelivered messages
  are restored from a backup file (`restore_messages = on`),
- message queue records are kept in an append-only log so they survive a restart,
- idle connections are dropped after 6 hours (`ttl = 21600`).

Your conversation history exists only in the encrypted database on your device. If you lose it, the
operator cannot restore it for you.

## What the app does not collect

- Creating a profile requires **no phone number, no email address and no username** on the server.
  The profile name is local data that you share with your contacts.
- The app contains **no ads, no analytics, no telemetry and no crash reporting**.
- The app connects to no third-party servers. The desktop build does not even check for updates.

## Calls and your IP address

Audio and video calls go through the TURN relay at `cht.macet.eu:3478`. The relay sees the duration
and volume of a call, not its content.

The **"Always use relay"** option (*Settings → Audio & video calls*) is **on by default**. If you
turn it off, the call is established directly between the devices and **the other party will see
your IP address**. Leave it on if that matters to you.

## Link previews

Link previews are **on by default**. While they are on, your device fetches the linked page, and
that page therefore sees your IP address. They can be turned off in *Settings → Privacy & security*.

## The limits of this document

The operator has full control over the server and nothing technically prevents changing the
configuration or the software so that it records more than is stated here. This document is a
statement of intent, not a technical guarantee.

The real guarantee is end-to-end encryption: even a server logging everything that passes through it
does not obtain the content of the messages. The app's source code is public and the build can be
verified against it.

## Changes

Changes to this document are visible in the repository's commit history.
