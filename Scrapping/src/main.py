import os
import asyncio
import shutil
import datetime
import csv
import pandas as pd

from urllib.parse import urljoin
from pathlib import Path
from google.cloud import storage
from playwright.async_api import async_playwright
from apify import Actor, Request

# Définir le chemin des credentials Google Cloud
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "mindful-hull-401711-b40850f2756a.json"
# Afficher le chemin d'accès du fichier de credentials
print("Chemin d'accès au fichier des credentials :", os.environ["GOOGLE_APPLICATION_CREDENTIALS"])

# Définir le dossier de téléchargement
download_path = Path(__file__).parent / "downloads"
download_path.mkdir(parents=True, exist_ok=True)
print(f'Le dossier "downloads" est prêt à : {download_path}')

# Initialiser le client Google Cloud Storage
storage_client = storage.Client()
bucket_name = "schoolmaker"
bucket = storage_client.bucket(bucket_name)

# Fonction pour supprimer tous les fichiers dans "downloads"
def delete_all_files_and_directories(directory_path):
    if directory_path.exists():
        shutil.rmtree(directory_path)
        directory_path.mkdir(parents=True, exist_ok=True)
        print(f'Tous les fichiers et sous-dossiers dans {directory_path} ont été supprimés.')

# Fonction pour trouver un fichier avec un préfixe spécifique
def find_downloaded_file(directory_path, file_prefix):
    for file in directory_path.iterdir():
        if file.is_file() and file.name.startswith(file_prefix):
            return file
    return None

# Fonction pour attendre un XPath
async def wait_for_xpath(page, xpath, timeout=30000):
    await page.wait_for_selector(f'xpath={xpath}', timeout=timeout)

# Fonction utilitaire pour ajouter un délai
async def delay(time: int):
    print(f"Attente de {time / 1000} secondes...")
    await asyncio.sleep(time / 1000)  # Le temps doit être en secondes pour asyncio.sleep

# Supprime un fichier existant dans un bucket GCS."""
def delete_old_file(bucket_name, file_name):
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(file_name)

    if blob.exists():
        blob.delete()
        print(f"Fichier {file_name} supprimé avec succès.")
    else:
        print(f"Fichier {file_name} non trouvé.")

async def main() -> None:
    """Main entry point for the Apify Actor."""
    async with Actor:
        actor_input = await Actor.get_input() or {}
  
        # Suppression des anciens fichiers avant téléchargement
        delete_all_files_and_directories(download_path)

        Actor.log.info('Launching Playwright....')
        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(
                headless=Actor.config.headless,
                args=['--disable-gpu', '--no-sandbox', '--disable-setuid-sandbox']
            )
            context = await browser.new_context(accept_downloads=True)
            page = await context.new_page()

            # Écouter l'événement de téléchargement
            download = None
            #page.on("download", lambda download_obj: download_obj.save_as(str(download_path / download_obj.suggested_filename)))
            page.on("download", lambda download_event: download_event.save_as(str(download_path / download_event.suggested_filename)))

            try:
                # 1. Connexion à SchoolMaker
                await page.goto('https://carteldeladata.schoolmaker.co/school-admin/login')
                await page.fill('#user_email', 'mathieu.chaine@gmail.com')
                await page.fill('#user_password', 'CY5$k@l*7x$R*6oa!8')
                await page.click('[name="button"]')
                await page.wait_for_url('https://carteldeladata.schoolmaker.co/school-admin/products')
                print('Connexion réussie')
                                
                # 2. Accéder à la page d'export de la progression
                await page.goto('https://carteldeladata.schoolmaker.co/school-admin/products/5d570c83-8fbf-4480-b642-f572856937b5')
                await page.get_by_role("link", name="Membres").click()
                await page.get_by_role('link', name='Exporter la progression').click()
                await page.goto('https://carteldeladata.schoolmaker.co/school-admin/exports/1a0ada6d-eab4-44b8-a944-b845466ff0f3')

                # Try clicking the export button
                xpath_button = '//header/div/div/form/button'
                MAX_RETRIES = 3
                retry_count = 0
                while retry_count < MAX_RETRIES:
                    #await page.pause()
                    await page.wait_for_selector(xpath_button)  # Attendre que le bouton soit visible
                    await page.click(xpath_button)  # Clic sur le bouton
                    await page.wait_for_timeout(2000)  # Allow time for navigation

                    # Check if 404 appears
                    if await page.get_by_text("404").is_visible():
                        print(f"❌ 404 detected! Attempt {retry_count + 1} of {MAX_RETRIES}. Going back...")
                        await page.go_back()
                        await page.wait_for_timeout(2000)  # Allow time to go back
                        retry_count += 1
                    else:
                        print("✅ Export page loaded successfully!")
                        break  # Exit loop if successful

                # If still failing after max retries, raise an error
                if retry_count == MAX_RETRIES:
                    raise Exception("❌ 404 error persisted after 3 attempts. Exiting.")

                    # Attendre 90 secondes (10000 millisecondes) puis recharger la page
                await delay(90000)
                try:
                    await page.reload(wait_until="load")  # Attendre jusqu'à ce que la page soit complètement chargée
                    print('Page rechargée')
                except Exception as e:
                    print(f'Erreur lors du rechargement de la page : {e}')
         
                # 3. Clic sur le bouton de téléchargement
                async with page.expect_download(timeout=60000) as download_info:
                    xpath_download_button = '//a[contains(@href, "eu-west")]'
                    await page.wait_for_selector(xpath_download_button, timeout=5000)
                    await page.click(xpath_download_button)
                download = await download_info.value
                await download.save_as(str(download_path / download.suggested_filename))
                print(f"Fichier téléchargé dans : {download_path}") 
                print("Contenu du dossier 'downloads' :")
                print(os.listdir('/usr/src/app/src/downloads'))  # Liste les fichiers et dossiers dans 'downloads'

                # 4. Renommer le fichier téléchargé
                try:
                    # Chercher et renommer le fichier téléchargé
                    file_prefix = 'product_5d570c83-8fbf-4480-b642-f572856937b5_members_progression_rate_export'
                    downloaded_file = find_downloaded_file(download_path, file_prefix)

                    if not downloaded_file:
                        print(f"Aucun fichier commençant par \"{file_prefix}\" n'a été trouvé dans {download_path}")
                    else:
                        original_file_path = os.path.join(download_path, downloaded_file)
                
                        # Nouveau nom fixe
                        new_file_name = 'members_progression_data_analyst_insider.csv'
                        new_file_path = os.path.join(download_path, new_file_name)
                        
                        # Créer un nom de fichier avec la date du jour
                        today_date = datetime.datetime.now().strftime('%Y-%m-%d')
                        new_file_with_date_name = f'members_progression_data_analyst_insider_{today_date}.csv'
                        new_file_with_date_path = os.path.join(download_path, new_file_with_date_name)

                        # Copier le fichier avec un nom fixe
                        shutil.copy(original_file_path, new_file_path)
                        print(f"Le fichier a été renommé en {new_file_name}")
                        
                        # Copier le fichier avec la date ajoutée au nom
                        shutil.copy(original_file_path, new_file_with_date_path)
                        print(f"Le fichier a été renommé avec la date en {new_file_with_date_name}")

                except Exception as e:
                    print(f"Erreur lors du renommage du fichier: {e}")
                
                # 5. Upload sur Google Cloud Storage
                try:
                    # 1. Upload du fichier avec le nom fixe
                    new_file_path_obj = Path(new_file_path)  # Convertir la chaîne en un objet Path
                    blob = bucket.blob(new_file_path_obj.name)  # Utiliser new_file_path_obj.name pour obtenir le nom du fichier
                    blob.upload_from_filename(str(new_file_path_obj))  # Utiliser str(new_file_path_obj) pour obtenir le chemin
                    print(f'Fichier envoyé vers {bucket_name} sous le nom {new_file_path_obj.name}')

                    # 2. Upload du fichier avec la date du jour dans le dossier "historic"
                    new_file_with_date_path_obj = Path(new_file_with_date_path)  # Convertir la chaîne en un objet Path
                    historic_blob = bucket.blob(f'historic/members_progression_data_analyst_insider/{new_file_with_date_path_obj.name}')  # Ajouter "historic/members_progression_data_analyst_insider" avant le nom
                    historic_blob.upload_from_filename(str(new_file_with_date_path_obj))  # Utiliser str(new_file_with_date_path_obj) pour obtenir le chemin
                    print(f'Fichier envoyé vers {bucket_name}/historic sous le nom {new_file_with_date_path_obj.name}')

                except Exception as e:
                    print(f"Erreur lors de l'upload des fichiers vers Google Cloud Storage : {e}")

                # 6. Accéder à la page d'export des membres
                await page.goto('https://carteldeladata.schoolmaker.co/school-admin/members')
                await page.get_by_role("button", name="Exporter").click()
                await page.get_by_role("link", name="Membres").click()
                await page.get_by_role("button", name="Exporter").click()
                await page.goto('https://carteldeladata.schoolmaker.co/school-admin/exports/d9ab6dae-d79b-4e2e-a6fe-ffa6e0b4c9cc')

                # Try clicking the export button
                xpath_button = '//header/div/div/form/button'
                MAX_RETRIES = 3
                retry_count = 0
                while retry_count < MAX_RETRIES:
                    #await page.pause()
                    await page.wait_for_selector(xpath_button)  # Attendre que le bouton soit visible
                    await page.click(xpath_button)  # Clic sur le bouton
                    await page.wait_for_timeout(2000)  # Allow time for navigation

                    # Check if 404 appears
                    if await page.get_by_text("404").is_visible():
                        print(f"❌ 404 detected! Attempt {retry_count + 1} of {MAX_RETRIES}. Going back...")
                        await page.go_back()
                        await page.wait_for_timeout(2000)  # Allow time to go back
                        retry_count += 1
                    else:
                        print("✅ Export page loaded successfully!")
                        break  # Exit loop if successful

                # If still failing after max retries, raise an error
                if retry_count == MAX_RETRIES:
                    raise Exception("❌ 404 error persisted after 3 attempts. Exiting.")

                # Attendre 90 secondes (5000 millisecondes) puis recharger la page
                await delay(90000)

                try:
                    await page.reload(wait_until="load")  # Attendre jusqu'à ce que la page soit complètement chargée
                    print('Page rechargée')
                except Exception as e:
                    print(f'Erreur lors du rechargement de la page : {e}')
         
                # 7. Clic sur le bouton de téléchargement
                async with page.expect_download(timeout=60000) as download_info:
                    xpath_download_button = '//a[contains(@href, "eu-west")]'
                    await page.wait_for_selector(xpath_download_button, timeout=5000)
                    await page.click(xpath_download_button)
                download = await download_info.value
                await download.save_as(str(download_path / download.suggested_filename))
                print(f"Fichier téléchargé dans : {download_path}") 
                print("Contenu du dossier 'downloads' :")
                print(os.listdir('/usr/src/app/src/downloads'))  # Liste les fichiers et dossiers dans 'downloads'

                # 8. Renommer le fichier téléchargé
                try:
                    # Chercher et renommer le fichier téléchargé
                    file_prefix = 'school_2a98e3e6-f072-42f7-a5ce-78eee4866abc_members_export'
                    downloaded_file = find_downloaded_file(download_path, file_prefix)

                    if not downloaded_file:
                        print(f"Aucun fichier commençant par \"{file_prefix}\" n'a été trouvé dans {download_path}")
                    else:
                        original_file_path = os.path.join(download_path, downloaded_file)
                
                        # Nouveau nom fixe
                        new_file_name = 'members_export.csv'
                        new_file_path = os.path.join(download_path, new_file_name)
                        
                        # Créer un nom de fichier avec la date du jour
                        today_date = datetime.datetime.now().strftime('%Y-%m-%d')
                        new_file_with_date_name = f'members_export_{today_date}.csv'
                        new_file_with_date_path = os.path.join(download_path, new_file_with_date_name)

                        # Copier le fichier avec un nom fixe
                        shutil.copy(original_file_path, new_file_path)
                        print(f"Le fichier a été renommé en {new_file_name}")
                        
                        # Copier le fichier avec la date ajoutée au nom
                        shutil.copy(original_file_path, new_file_with_date_path)
                        print(f"Le fichier a été renommé avec la date en {new_file_with_date_name}")

                except Exception as e:
                    print(f"Erreur lors du renommage du fichier: {e}")
                
                # 5. Upload sur Google Cloud Storage
                try:
                    # 1. Upload du fichier avec le nom fixe
                    new_file_path_obj = Path(new_file_path)  # Convertir la chaîne en un objet Path
                    blob = bucket.blob(new_file_path_obj.name)  # Utiliser new_file_path_obj.name pour obtenir le nom du fichier
                    blob.upload_from_filename(str(new_file_path_obj))  # Utiliser str(new_file_path_obj) pour obtenir le chemin
                    print(f'Fichier envoyé vers {bucket_name} sous le nom {new_file_path_obj.name}')

                    # 2. Upload du fichier avec la date du jour dans le dossier "historic"
                    new_file_with_date_path_obj = Path(new_file_with_date_path)  # Convertir la chaîne en un objet Path
                    historic_blob = bucket.blob(f'historic/members_export/{new_file_with_date_path_obj.name}')  # Ajouter "historic/members_progression_data_analyst_insider" avant le nom
                    historic_blob.upload_from_filename(str(new_file_with_date_path_obj))  # Utiliser str(new_file_with_date_path_obj) pour obtenir le chemin
                    print(f'Fichier envoyé vers {bucket_name}/historic sous le nom {new_file_with_date_path_obj.name}')

                except Exception as e:
                    print(f"Erreur lors de l'upload des fichiers vers Google Cloud Storage : {e}")

                # 10. Accéder à la page d'export des actions des membres
                await page.goto('https://carteldeladata.schoolmaker.co/school-admin/members')
                await page.get_by_role("button", name="Exporter").click()
                await page.get_by_role("menuitem", name="Activité des membres").click()
                await page.get_by_role("button", name="Exporter").click()
                await page.goto('https://carteldeladata.schoolmaker.co/school-admin/exports/34966d4d-f894-4687-b86e-14e9cd9177b6')

                # Try clicking the export button
                xpath_button = '//header/div/div/form/button'
                MAX_RETRIES = 3
                retry_count = 0
                while retry_count < MAX_RETRIES:
                    #await page.pause()
                    await page.wait_for_selector(xpath_button)  # Attendre que le bouton soit visible
                    await page.click(xpath_button)  # Clic sur le bouton
                    await page.wait_for_timeout(2000)  # Allow time for navigation

                    # Check if 404 appears
                    if await page.get_by_text("404").is_visible():
                        print(f"❌ 404 detected! Attempt {retry_count + 1} of {MAX_RETRIES}. Going back...")
                        await page.go_back()
                        await page.wait_for_timeout(2000)  # Allow time to go back
                        retry_count += 1
                    else:
                        print("✅ Export page loaded successfully!")
                        break  # Exit loop if successful

                # If still failing after max retries, raise an error
                if retry_count == MAX_RETRIES:
                    raise Exception("❌ 404 error persisted after 3 attempts. Exiting.")

                # Attendre 500 secondes (500000 millisecondes) puis recharger la page
                await delay(500000)
                try:
                    await page.reload(wait_until="load")  # Attendre jusqu'à ce que la page soit complètement chargée
                    print('Page rechargée')
                except Exception as e:
                    print(f'Erreur lors du rechargement de la page : {e}')
         
                # 7. Clic sur le bouton de téléchargement
                async with page.expect_download(timeout=60000) as download_info:
                    xpath_download_button = '//a[contains(@href, "eu-west")]'
                    await page.wait_for_selector(xpath_download_button, timeout=5000)
                    await page.click(xpath_download_button)
                download = await download_info.value
                await download.save_as(str(download_path / download.suggested_filename))
                print(f"Fichier téléchargé dans : {download_path}") 
                print("Contenu du dossier 'downloads' :")
                print(os.listdir('/usr/src/app/src/downloads'))  # Liste les fichiers et dossiers dans 'downloads'

                # 8. Renommer le fichier téléchargé
                try:
                    # Chercher et renommer le fichier téléchargé
                    file_prefix = 'school_2a98e3e6-f072-42f7-a5ce-78eee4866abc_members_events_export'
                    downloaded_file = find_downloaded_file(download_path, file_prefix)

                    if not downloaded_file:
                        print(f"Aucun fichier commençant par \"{file_prefix}\" n'a été trouvé dans {download_path}")
                    else:
                        df = pd.read_csv(downloaded_file)
                        df = df.replace('\n', '', regex=True)
                        df.columns = ['Email_du_membre', 'Action', 'Programme', 'Espace', 'Duree_action', 'IP', 'Fait_le']
                        df.to_csv(downloaded_file, index=False, quoting=csv.QUOTE_NONNUMERIC)

                        original_file_path = os.path.join(download_path, downloaded_file)
                
                        # Nouveau nom fixe
                        new_file_name = 'members_events_export.csv'
                        new_file_path = os.path.join(download_path, new_file_name)
                        
                        # Créer un nom de fichier avec la date du jour
                        today_date = datetime.datetime.now().strftime('%Y-%m-%d')
                        new_file_with_date_name = f'members_events_export_{today_date}.csv'
                        new_file_with_date_path = os.path.join(download_path, new_file_with_date_name)

                        # Copier le fichier avec un nom fixe
                        shutil.copy(original_file_path, new_file_path)
                        print(f"Le fichier a été renommé en {new_file_name}")
                        
                        # Copier le fichier avec la date ajoutée au nom
                        shutil.copy(original_file_path, new_file_with_date_path)
                        print(f"Le fichier a été renommé avec la date en {new_file_with_date_name}")

                except Exception as e:
                    print(f"Erreur lors du renommage du fichier: {e}")
                
                # 5. Upload sur Google Cloud Storage
                try:
                    # 1. Upload du fichier avec le nom fixe
                    new_file_path_obj = Path(new_file_path)  # Convertir la chaîne en un objet Path
                    blob = bucket.blob(new_file_path_obj.name)  # Utiliser new_file_path_obj.name pour obtenir le nom du fichier
                    blob.upload_from_filename(str(new_file_path_obj))  # Utiliser str(new_file_path_obj) pour obtenir le chemin
                    print(f'Fichier envoyé vers {bucket_name} sous le nom {new_file_path_obj.name}')

                    # 2. Upload du fichier avec la date du jour dans le dossier "historic"
                    new_file_with_date_path_obj = Path(new_file_with_date_path)  # Convertir la chaîne en un objet Path
                    historic_blob = bucket.blob(f'historic/members_events_export/{new_file_with_date_path_obj.name}')  # Ajouter "historic/members_progression_data_analyst_insider" avant le nom
                    historic_blob.upload_from_filename(str(new_file_with_date_path_obj))  # Utiliser str(new_file_with_date_path_obj) pour obtenir le chemin
                    print(f'Fichier envoyé vers {bucket_name}/historic/members_events_export sous le nom {new_file_with_date_path_obj.name}')

                except Exception as e:
                    print(f"Erreur lors de l'upload des fichiers vers Google Cloud Storage : {e}")

                ### Ajout du fichier files_last_update ###
                # Récupération des noms et date de modifications des fichiers dans un JSON
                try:
                    # Afficher les noms + date de création
                    data_json = []
                    blobs = storage_client.list_blobs(bucket)
                    for blob in blobs:
                        if blob.name[:9] != "historic/" and blob.name[-4:] == ".csv":
                            data_json.append({
                                "filename": blob.name[:-4],
                                "updated": blob.time_created.strftime('%Y-%m-%d %H:%M:%S')
                            })
                    print(f'Data récupéré depuis le bucket')
                except Exception as e:
                    print(f"Erreur lors la récupération des données depuis le bucket")

                # Création du CSV
                try:
                    # 1. Upload du fichier sur le bucket
                    file_name = "file_last_update.csv"
                    # transformation en dataframe
                    df = pd.DataFrame(data_json)
                    # transformation en fichiers.csv
                    df.to_csv(file_name, index=False)
                    print(f'Fichier créé sous le nom de {file_name}')
                except Exception as e:
                    print(f"Erreur lors la création du fichier csv")

                # Upload sur Google Cloud Storage
                try:
                    # 1. Upload du fichier sur le bucket
                    blob = bucket.blob(file_name)
                    blob.upload_from_filename(file_name)
                    print(f'Fichier envoyé vers {bucket_name} sous le nom {file_name}')
                except Exception as e:
                    print(f"Erreur lors de l'upload des fichiers vers Google Cloud Storage : {e}")

            finally:
                await browser.close()

# Exécuter le crawler
asyncio.run(main())