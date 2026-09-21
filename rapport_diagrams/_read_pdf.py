import pdfplumber

path = r"C:\Users\user\Downloads\Rapport_du_projet___application_de_livraison (1).pdf"
with pdfplumber.open(path) as pdf:
    print(f"Total pages: {len(pdf.pages)}")
    for i, page in enumerate(pdf.pages, 1):
        text = page.extract_text()
        print(f"\n{'='*60}")
        print(f"PAGE {i}")
        print('='*60)
        if text:
            print(text)
        else:
            print("[pas de texte extractible]")
