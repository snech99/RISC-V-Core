# start.S

# Wir definieren eine spezielle Sektion namens ".init".
# Diese Sektion werden wir im Linker-Skript an Adresse 0 zwingen.
.section .init, "ax"
.global _start

_start:
    # 1. Stack-Pointer (sp / r2) initialisieren.
    # Dein RAM ist 4096 Bytes groß. Der Stack wächst nach unten.
    li sp, 4096

    # 2. Ins C-Programm springen!
    call main

    # 3. Halt-Schleife (Der Sicherheitsnetz-Halt)
    # Falls die main() Funktion jemals (aus Versehen) verlassen wird,
    # fangen wir die CPU hier in einer Endlosschleife auf, 
    # damit sie keinen Müll im restlichen Speicher ausführt.
halt:
    j halt