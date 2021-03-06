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
	port            = flag.Int("port", 2222, "SSH server port")
	hostKeyFilePath = flag.String("host-key", "id_rsa", "ID RSA SSH Host key")
	serverAvailableFlagPath = "/tmp/browsh-ssh-server-available"
	isServerBusy = false
)

type winsize struct {
	Row    uint16
	Col    uint16
	Xpixel uint16
	Ypixel uint16
}

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

	// TODO: Shouldn't most of these be automatically set?
	child.Env = append(child.Env, "TERM=xterm-256color")
	child.Env = append(child.Env, "LC_ALL=en_US.UTF-8")
	child.Env = append(child.Env, "PATH=/app/bin/firefox:/usr/local/bin:/usr/bin:/bin")
	child.Env = append(child.Env, "HOME=/app")
	child.Env = append(child.Env, "SHELL=/usr/bin/bash")
	return child
}

func setWinsize(f *os.File, w, h int) {
	syscall.Syscall(syscall.SYS_IOCTL, f.Fd(), uintptr(syscall.TIOCSWINSZ),
		uintptr(unsafe.Pointer(&struct{ h, w, x, y uint16 }{uint16(h), uint16(w), 0, 0})))
}

func getWinsize(f *os.File) *winsize {
	ws := &winsize{}
	retCode, _, errno := syscall.Syscall(syscall.SYS_IOCTL,
		f.Fd(),
		uintptr(syscall.TIOCGWINSZ),
		uintptr(unsafe.Pointer(ws)))
	if int(retCode) == -1 {
		panic(errno)
	}
	return ws
}

func startPTY(sshSession ssh.Session, child *exec.Cmd, winCh <-chan ssh.Window) {
	ptyFile, err := pty.Start(child)
	if err != nil {
		panic(err)
	}
	go func() {
		setWinsize(ptyFile, 80, 30)
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
	ssh.Handle(handleSSHConnection)
	portString := strconv.Itoa(*port)
	log.Println("Starting Browsh-dedicated SSH server on port " + portString)
	markServerAvailable()
	log.Fatal(ssh.ListenAndServe(":"+portString, nil, ssh.HostKeyFile(*hostKeyFilePath)))
}

func handleSSHConnection(sshSessionScoped ssh.Session) {
	sshSession = sshSessionScoped
	// This relies on the reliability of Nginx-Ingress' `least-conn` loadbalancing
	// alogrithm.
	if (isServerBusy) {
		io.WriteString(
			sshSession,
			"All of Browsh's servers are currently busy. Please try again soon.\n")
		sshSession.Exit(0)
		return
	}
	markServerBusy()
	log.Println("New SSH session:",
		map[string]interface{}{
			"address": sshSession.RemoteAddr(),
			"user":    sshSession.User(),
			"command": sshSession.Command(),
		},
	)
	var child = setupChildProcess(sshSession.Command())
	child.Env = append(child.Env, "SSH_USER=" + sshSession.User())
	_, winCh, isPty := sshSession.Pty()
	if isPty {
		startPTY(sshSession, child, winCh)
	} else {
		io.WriteString(sshSession, "No PTY requested.\n")
		markServerAvailable()
		sshSession.Exit(1)
		return
	}

	killFirefox()
	// TODO: Also remove profile
	markServerAvailable()
}

func killFirefox() {
	cmd := "kill $(ps aux|grep headless|tr -s ' ' | cut -d ' ' -f2)"
	out, err := exec.Command("bash", "-c", cmd).Output()
	if string(out) != "" {
		log.Println("Killed Firefox: " + string(out))
	}
	if err != nil {
		log.Println("Error killing Firefox")
		log.Println(err)
		out, _ := exec.Command("ps", "aux").Output()
		log.Println("ps aux: \n" + string(out))
	}
}

// TODO: These don't have to store to a file. That's just a legacy of trying to use
// Kubernetes' readyStatus to limit pods to 1 connection.
func markServerAvailable() {
	isServerBusy = false
	if _, err := os.Stat(serverAvailableFlagPath); os.IsNotExist(err) {
		var file, err = os.Create(serverAvailableFlagPath)
		if err != nil {
			log.Println(err.Error())
		}
		defer file.Close()
	}
}

func markServerBusy() {
	isServerBusy = true
	if _, err := os.Stat(serverAvailableFlagPath); err == nil {
		var err = os.Remove(serverAvailableFlagPath)
		if err != nil {
			log.Println(err.Error())
		}
	}
}

func main() {
	flag.Parse()
	startSSHServer()
}
