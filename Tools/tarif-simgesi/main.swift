import Foundation

// Windows programındaki simgeyi .ico olarak yazar (KopruCore/WindowsIcon.swift ile birlikte derlenir).
let args = CommandLine.arguments
guard args.count == 3, let ico = WindowsIcon.icoData(fromExecutable: URL(fileURLWithPath: args[1])) else {
    FileHandle.standardError.write(Data("kullanım: tarif-simgesi <program.exe> <çıktı.ico>\n".utf8))
    exit(1)
}
try ico.write(to: URL(fileURLWithPath: args[2]))
