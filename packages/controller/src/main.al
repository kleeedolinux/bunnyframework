# bunny: entrypoint only. All behavior lives in BunnyCli.
args = List(String).new
all = System.Environment.GetCommandLineArgs
for i in 1...all.size
  args << all[i]
end
System.Environment.Exit(BunnyCli::Cli.run(args))
