# codespace-bootstrap
auto load tmux and nvim onto debian x86_64 terminal.

# 1) From your codespace shell

```
cd ~
git clone https://github.com/mjm41/codespace-bootstrap.git ~/codespace-bootstrap
```

# 2) (Optional but smart) inspect the script before running

```
sed -n '1,200p' ~/codespace-bootstrap/install.sh
```

# 3) Execute it

```
bash ~/codespace-bootstrap/install.sh
```
