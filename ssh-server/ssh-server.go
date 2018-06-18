package main

import (
	"flag"
	"io"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"unsafe"

	"github.com/gliderlabs/ssh"
	"github.com/kr/pty"
)

var (
	sshSession      ssh.Session
	googleProjectID = os.Getenv("GOOGLE_PROJECT_ID")
	port            = flag.Int("port", 22, "SSH server port")
	hostKeyFilePath = flag.String("host-key", "/etc/browsh/browsh_id_rsa", "ID RSA SSH Host key")
)

func setupChildProcess(commandSentWithSSHSession []string) *exec.Cmd {
	var forceCommand = "start-browsh-session.sh"
	var child = exec.Command(forceCommand)

	if len(commandSentWithSSHSession) > 0 {
		if (commandSentWithSSHSession[0] == "mosh-server") {
			forceCommand = "mosh-server new -c 256 -- " + forceCommand
			commandsToUse := strings.Fields(forceCommand)
			child = exec.Command(commandsToUse[0], commandsToUse[1:]...)
		}
		lastCommand := commandSentWithSSHSession[len(commandSentWithSSHSession)-1]
		if (strings.HasPrefix(lastCommand, "http")) {
			url := lastCommand
			if (!strings.ContainsAny(url, "$ | ` | \\ | ! | '")) {
				child.Env = append(child.Env, "BROWSH_URL=" + url)
			}
		}
	}

	// Set the user:group to `user:docker`
	child.SysProcAttr = &syscall.SysProcAttr{}
	child.SysProcAttr.Credential = &syscall.Credential{Uid: 1000, Gid: 999}
	// TODO: Shouldn't most of these be automatically set?
	child.Env = append(child.Env, "TERM=xterm-256color")
	child.Env = append(child.Env, "LC_ALL=en_US.UTF-8")
	child.Env = append(child.Env, "PATH=/usr/local/bin:/usr/bin:/bin")
	child.Env = append(child.Env, "HOME=/home/user")
	child.Env = append(child.Env, "SHELL=/usr/bin/bash")

	return child
}

func setWinsize(f *os.File, w, h int) {
	syscall.Syscall(syscall.SYS_IOCTL, f.Fd(), uintptr(syscall.TIOCSWINSZ),
		uintptr(unsafe.Pointer(&struct{ h, w, x, y uint16 }{uint16(h), uint16(w), 0, 0})))
}

func startPTY(sshSession ssh.Session, child *exec.Cmd, winCh <-chan ssh.Window) {
	ptyFile, err := pty.Start(child)
	if err != nil {
		panic(err)
	}
	go func() {
		for win := range winCh {
			setWinsize(ptyFile, win.Width, win.Height)
		}
	}()
	go func() {
		io.Copy(ptyFile, sshSession) // stdin
	}()
	io.Copy(sshSession, ptyFile) // stdout
}

func startSSHServer() {
	ssh.Handle(func(sshSessionScoped ssh.Session) {
		sshSession = sshSessionScoped
		log.Println("New SSH session:",
			map[string]interface{}{
				"address": sshSession.RemoteAddr(),
				"user":    sshSession.User(),
				"command": sshSession.Command(),
			},
		)
		var child = setupChildProcess(sshSession.Command())
		child.Env = append(child.Env, "BROWSH_USER=" + sshSession.User())
		_, winCh, isPty := sshSession.Pty()
		if isPty {
			startPTY(sshSession, child, winCh)
		} else {
			io.WriteString(sshSession, "No PTY requested.\n")
			sshSession.Exit(1)
		}
	})

	portString := strconv.Itoa(*port)
	log.Println("Starting Browsh-dedicated SSH server on port " + portString)
	ssh.ListenAndServe(":"+portString, nil, ssh.HostKeyFile(*hostKeyFilePath))
}

func main() {
	flag.Parse()
	startSSHServer()
}
