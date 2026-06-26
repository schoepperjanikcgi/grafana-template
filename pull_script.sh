# eval "$(ssh-agent -s)"
# ssh-add ~/.ssh/id_ed25519 # add your SSH private key to the ssh-agent

git pull --rebase

cd ..

coder templates pull grafana-template --version active -y

cd grafana-template/

# I guess we use VSCode anywany so we dont really need to run git diff
#git diff
