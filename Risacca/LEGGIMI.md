# Risacca per FreeBSD 15.1 amd64

Questo progetto genera un DVD di installazione personalizzato per PC Intel e AMD a 64 bit. L'installazione è guidata da bsdinstall. Dopo il riavvio, LightDM apre la sessione Xfce dell'utente creato durante l'installazione. Il profilo include una barra superiore, un dock centrale, icone Papirus, uno sfondo originale e collegamenti a Firefox ESR, Thunar, Mousepad e al terminale. Include anche LibreOffice e VLC.

## Generare l'ISO

Usare una macchina FreeBSD 15.1-RELEASE amd64, anche virtuale, con connessione Internet e spazio per il DVD di base, la sua estrazione, i pacchetti e la nuova immagine. Come stima di lavoro, riservare 30 GB liberi su un filesystem Unix che supporti file superiori a 5 GB. Estrarre il progetto in un percorso senza spazi. Eseguire come root, dalla directory del progetto.

```sh
pkg install -y git
sh build.sh
```

Il risultato è `out/Risacca-15.1-amd64.iso`. Nella stessa directory viene scritto il checksum SHA-256. La build verifica il DVD di partenza con l'hash pubblicato da FreeBSD, controlla il tag Git, risolve le dipendenze sul catalogo offline, controlla le voci del catalogo di avvio BIOS e UEFI e richiede almeno 5.000.000.000 byte. Tutto lo spazio dipende dai file inclusi. Il percorso dei file intermedi viene stampato a fine build.

Il sistema di base proviene dal DVD binario ufficiale 15.1-RELEASE. Per la creazione del supporto viene usato `release/amd64/mkisoimages.sh` dal tag `release/15.1.0` del repository richiesto. Applicazioni e firmware provengono dai repository pkg configurati nella macchina FreeBSD di build. Usare la configurazione ufficiale per 15.1 con il repository dei moduli kernel abilitato. Le versioni dei pacchetti possono cambiare fra due build. L'inventario e il commit dei sorgenti sono registrati nell'ISO sotto `/risacca`.

La build su GitHub Actions avvia l’ISO in due VM QEMU senza disco né rete, prima con BIOS e poi con UEFI. Il test controlla che entrambe arrivino alla schermata di benvenuto di bsdinstall.

## Avvio e installazione

Collegare l'ISO come lettore ottico a una VM amd64 e avviarla. Selezionare **Install**. Per usare il contenuto offline, scegliere i set locali del DVD quando viene proposta una sorgente di installazione. Creare un utente ordinario quando bsdinstall lo propone. Il profilo desktop viene installato alla fine, prima del riavvio. Rimuovere il supporto virtuale e accedere con l'utente appena creato. Per provare il programma di installazione, scegliere un disco virtuale vuoto. Il partizionamento scrive sul disco selezionato.

La configurazione di rete del programma di installazione permette di scegliere una scheda e una rete Wi-Fi rilevate. Il sistema installato include wifimgr e i firmware del metapacchetto FreeBSD wifi-firmware-kmod. Per verificare il riconoscimento della scheda usare `sysctl net.wlan.devices`. Per il Bluetooth USB il profilo abilita ng_ubt e hcsecd e include i firmware Intel e Realtek. Come root, con un adattatore compatibile, `ngctl list` mostra i nodi Bluetooth e `hccontrol -n ubt0hci inquiry` cerca dispositivi visibili. Sostituire il nome del nodo con quello effettivo.

La compatibilità dipende dal modello di GPU e dal chipset radio. Il supporto include DRM per Intel e AMD e i driver grafici di ripiego SCFB e VESA. Su un sistema che richiede il caricamento esplicito del modulo grafico, usare il modulo indicato per la propria scheda nel capitolo X Window System del manuale FreeBSD. La presenza del firmware Bluetooth non garantisce ogni profilo, per esempio l'audio delle cuffie. Un test in VM può verificare l'installazione e il desktop. Per verificare Wi-Fi e Bluetooth serve il dispositivo corrispondente.

## Riferimenti

- [Sorgenti FreeBSD 15.1](https://github.com/freebsd/freebsd-src/tree/release/15.1.0)
- [DVD di partenza e checksum](https://www.freebsd.org/releases/15.1R/announce/)
- [Hardware supportato](https://www.freebsd.org/releases/15.1R/hardware/)
- [Configurazione grafica](https://docs.freebsd.org/en/books/handbook/x11/)
- [Wi-Fi](https://docs.freebsd.org/en/books/handbook/network/)
- [Bluetooth](https://docs.freebsd.org/en/books/handbook/advanced-networking/#network-bluetooth)
