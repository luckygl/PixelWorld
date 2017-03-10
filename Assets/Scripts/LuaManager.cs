﻿using UnityEngine;
using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using LuaInterface;

public class LuaManager : MonoBehaviour {

	private static LuaManager _instance;
	public static LuaManager GetInstance(bool bCreate=false) {
		if (bCreate == false) return _instance;

		GameObject main = GameObject.Find("Main");
		if (main == null) {
			main = new GameObject("Main");
			DontDestroyOnLoad(main);
		}
		if (_instance == null) {
			_instance = main.AddComponent<LuaManager>();
		}
		return _instance;
	}

        private LuaState lua;
        private LuaLooper loop = null;

        // Use this for initialization
	void Awake() {
		LuaFileUtils loader = new LuaResLoader();
		loader.beZip = GameConfig.EnableUpdate;	// 是否读取assetbundle lua文件

		//add lua assetbundle
		Dictionary<string, AssetBundle> assetBundles = AssetBundleManager.GetInstance().LoadedAssetBundles;
		foreach(string assetBundleName in assetBundles.Keys) {
			string name = Path.GetFileNameWithoutExtension(assetBundleName);
			LuaFileUtils.Instance.AddSearchBundle(name, assetBundles[assetBundleName]);
		}

		lua = new LuaState();
		this.OpenLibs();
		lua.LuaSetTop(0);

		LuaBinder.Bind(lua);
		LuaCoroutine.Register(lua, this);
        }

        public void InitStart() {
            InitLuaPath();
            InitLuaBundle();
            this.lua.Start();    //启动LUAVM
            this.StartMain();
            this.StartLooper();
        }

        void StartLooper() {
            loop = gameObject.AddComponent<LuaLooper>();
            loop.luaState = lua;
        }

        //cjson 比较特殊，只new了一个table，没有注册库，这里注册一下
        protected void OpenCJson() {
            lua.LuaGetField(LuaIndexes.LUA_REGISTRYINDEX, "_LOADED");
            lua.OpenLibs(LuaDLL.luaopen_cjson);
            lua.LuaSetField(-2, "cjson");

            lua.OpenLibs(LuaDLL.luaopen_cjson_safe);
            lua.LuaSetField(-2, "cjson.safe");
        }

        void StartMain() {
            lua.DoFile("Main.lua");

            LuaFunction main = lua.GetFunction("Main");
            main.Call();
            main.Dispose();
            main = null;    
        }
        
        /// <summary>
        /// 初始化加载第三方库
        /// </summary>
        void OpenLibs() {
            lua.OpenLibs(LuaDLL.luaopen_pb);
            lua.OpenLibs(LuaDLL.luaopen_lpeg);
            lua.OpenLibs(LuaDLL.luaopen_bit);
            lua.OpenLibs(LuaDLL.luaopen_socket_core);

            this.OpenCJson();
        }

        /// <summary>
        /// 初始化Lua代码加载路径
        /// </summary>
        void InitLuaPath() {
		lua.AddSearchPath(Application.dataPath + "/Lua");
		lua.AddSearchPath(Application.dataPath + "/ToLua/Lua");
        }

        /// <summary>
        /// 初始化LuaBundle
        /// </summary>
        void InitLuaBundle() {
		
        }

        public object[] DoFile(string filename) {
		return lua.DoFile(filename);
        }

        // Update is called once per frame
        public object[] CallFunction(string funcName, params object[] args) {
		LuaFunction func = lua.GetFunction(funcName);
		if (func != null) {
			return func.Call(args);
		}
		return null;
        }

        public void LuaGC() {
            lua.LuaGC(LuaGCOptions.LUA_GCCOLLECT);
        }

        public void Close() {
            loop.Destroy();
            loop = null;

            lua.Dispose();
            lua = null;
        }
}