from pathlib import Path
import ast,json,os,subprocess,sys,tempfile,unittest
ROOT=Path(__file__).resolve().parents[1]

class Jobs(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
  modules=self.root/'modules';modules.mkdir()
  for name in ('torch','transformers','datasets','accelerate'):(modules/(name+'.py')).write_text('')
  binary=self.root/'bin';binary.mkdir()
  scheduler=binary/'sbatch';scheduler.write_text('#!'+sys.executable+'\nimport json,os,sys\nopen(os.environ["ARGV"],"w").write(json.dumps(sys.argv[1:]))\nprint("12345")\nsys.exit(int(os.environ.get("SUBMIT_EXIT","0")))\n');scheduler.chmod(0o700)
  (self.root/'lock').write_text('locked fixture')
  self.env={**os.environ,'PYTHONPATH':str(modules),'PATH':str(binary)+os.pathsep+os.environ['PATH'],
   'SLURM_ACCOUNT':'project-account','SLURM_PARTITION':'alpha','LUSTRE_ROOT':str(self.root),
   'SMOKE_PYTHON':sys.executable,'SMOKE_LOCKFILE':str(self.root/'lock'),
   'MODEL_REVISION':'a'*40,'DATASET_REVISION':'b'*40,'SMOKE_MIN_ACCURACY':'0.8','ARGV':str(self.root/'argv')}
 def tearDown(self):self.temp.cleanup()
 def submit(self):return subprocess.run(['bash',str(ROOT/'assets/smoke_test.sh')],env=self.env,capture_output=True,text=True)
 def test_unique_runs_and_explicit_routing(self):
  first=self.submit();self.assertEqual(first.returncode,0,first.stderr)
  run=next((self.root/'smoke-runs').iterdir());(run/'keep').write_text('prior')
  second=self.submit();self.assertEqual(second.returncode,0,second.stderr)
  self.assertEqual(len(list((self.root/'smoke-runs').iterdir())),2);self.assertTrue((run/'keep').exists())
  args=json.loads((self.root/'argv').read_text());self.assertEqual(args[args.index('--account')+1],'project-account');self.assertEqual(args[args.index('--partition')+1],'alpha')
  self.assertTrue((run/'manifest.json').exists());self.assertIn('Verification pending',first.stdout)
 def test_missing_account_fails_before_side_effects(self):
  del self.env['SLURM_ACCOUNT'];result=self.submit();self.assertNotEqual(result.returncode,0)
  self.assertFalse((self.root/'smoke-runs').exists());self.assertFalse((self.root/'argv').exists())
 def test_missing_interpreter_never_falls_back(self):
  self.env['SMOKE_PYTHON']=str(self.root/'absent');self.assertNotEqual(self.submit().returncode,0);self.assertFalse((self.root/'argv').exists())
 def test_invalid_threshold_and_floating_revision_rejected(self):
  self.env['SMOKE_MIN_ACCURACY']='nan';self.assertNotEqual(self.submit().returncode,0)
  self.env['SMOKE_MIN_ACCURACY']='0.8';self.env['MODEL_REVISION']='main';self.assertNotEqual(self.submit().returncode,0)
  self.assertFalse((self.root/'smoke-runs').exists())
 def test_optimized_python_rejects_nan_at_both_boundaries(self):
  self.env['PYTHONOPTIMIZE']='1';self.env['SMOKE_MIN_ACCURACY']='nan'
  self.assertNotEqual(self.submit().returncode,0);self.assertFalse((self.root/'argv').exists())
  result=subprocess.run([sys.executable,str(ROOT/'assets/train_smoke.py')],env=self.env,capture_output=True,text=True)
  self.assertNotEqual(result.returncode,0);self.assertIn('invalid accuracy threshold',result.stderr)
 def test_uncertain_submission_preserves_run_without_success(self):
  self.env['SUBMIT_EXIT']='1';result=self.submit();self.assertNotEqual(result.returncode,0)
  run=next((self.root/'smoke-runs').iterdir());self.assertFalse((run/'job-id.txt').exists());self.assertIn('unresolved',result.stderr)
 def test_template_fails_missing_environment(self):
  env={**self.env,'PROJECT_PYTHON':str(self.root/'absent'),'TRAIN_SCRIPT':str(ROOT/'assets/train_smoke.py'),'HF_HOME':str(self.root)}
  result=subprocess.run(['bash',str(ROOT/'assets/job_template.sbatch')],env=env,capture_output=True)
  self.assertNotEqual(result.returncode,0)
 def test_shell_and_python_syntax(self):
  for name in ('smoke_test.sh','job_template.sbatch'):subprocess.run(['bash','-n',str(ROOT/'assets'/name)],check=True)
  ast.parse((ROOT/'assets/train_smoke.py').read_text())

if __name__=='__main__':unittest.main()
