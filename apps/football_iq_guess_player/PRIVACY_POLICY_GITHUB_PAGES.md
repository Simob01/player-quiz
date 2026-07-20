# Publish the Privacy Policy on GitHub Pages

Use `privacy_policy.html` as the public privacy policy page for Google Play.

## Option A: Publish from a GitHub Pages `docs/` Folder

1. Create a `docs/` folder at the repository root.
2. Copy `apps/football_iq_guess_player/privacy_policy.html` into `docs/privacy_policy.html`.
3. Commit and push the `docs/privacy_policy.html` file.
4. In GitHub, open the repository settings.
5. Go to **Pages**.
6. Under **Build and deployment**, choose:
   - Source: **Deploy from a branch**
   - Branch: your main branch
   - Folder: `/docs`
7. Save.
8. After GitHub Pages finishes publishing, your URL should look like:

```text
https://YOUR_GITHUB_USERNAME.github.io/YOUR_REPOSITORY_NAME/privacy_policy.html
```

9. Paste that URL into the Google Play Console privacy policy field.

## Option B: Publish from the Repository Root

1. Place `privacy_policy.html` at the repository root.
2. Commit and push it.
3. In GitHub Pages settings, choose the root folder for the selected branch.
4. Use the generated GitHub Pages URL in Google Play Console.

## Update Checklist

Update the policy before publishing a new app version if you add:

- Firebase Analytics or another analytics provider
- Login or account creation
- Cloud sync
- Payments or subscriptions
- New ad networks
- Collection of names, emails, phone numbers, location, contacts, photos, or other personal data

Keep the contact email as:

```text
cahsforphones48@gmail.com
```
