from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy import Column, String, Text, text, BigInteger
from contextlib import asynccontextmanager
from logger import info, error
from config import DATABASE_URL
import asyncio
import time


# 基础模型类
class Base(DeclarativeBase):
    pass


# 账号模型
class AccountModel(Base):
    __tablename__ = "accounts"
    email = Column(String(255), primary_key=True)
    user = Column(String(255), nullable=False)
    password = Column(String(255), nullable=True)
    token = Column(String(255), nullable=False)
    usage_limit = Column(Text, nullable=True)
    created_at = Column(Text, nullable=True)
    status = Column(String(50), default="active", nullable=False)
    id = Column(BigInteger, nullable=False, index=True)  # 添加毫秒时间戳列并创建索引


# 全局引擎和会话工厂
_engine = None
_session_factory = None


# 创建数据库引擎，支持重试机制
async def create_db_engine(max_retries=5, retry_interval=5):
    """创建数据库引擎，支持重试机制"""
    global _engine
    
    # 如果引擎已存在，直接返回
    if _engine is not None:
        return _engine
        
    for attempt in range(max_retries):
        try:
            # 创建引擎
            _engine = create_async_engine(
                DATABASE_URL, 
                echo=False,
                future=True,
                pool_pre_ping=True,  # 连接前ping一下，确保连接有效
                pool_recycle=3600,   # 一小时后回收连接
                pool_size=5,         # 连接池大小
                max_overflow=10      # 最大溢出连接数
            )
            
            # 只在首次创建时测试连接
            async with _engine.begin() as conn:
                await conn.execute(text("SELECT 1"))
            
            info(f"成功连接到数据库: {DATABASE_URL}")
            return _engine
        except Exception as e:
            error(f"数据库连接失败 (尝试 {attempt+1}/{max_retries}): {str(e)}")
            if attempt < max_retries - 1:
                await asyncio.sleep(retry_interval)
            else:
                error("达到最大重试次数，无法连接到数据库")
                raise


# 获取会话工厂
async def get_session_factory():
    """获取会话工厂，如果不存在则创建"""
    global _session_factory, _engine
    
    if _session_factory is None:
        if _engine is None:
            _engine = await create_db_engine()
        _session_factory = async_sessionmaker(
            _engine, class_=AsyncSession, expire_on_commit=False, future=True
        )
    
    return _session_factory


@asynccontextmanager
async def get_session() -> AsyncSession:
    """获取数据库异步会话"""
    session_factory = await get_session_factory()
    session = session_factory()
    
    try:
        yield session
    except Exception as e:
        error(f"数据库会话错误: {str(e)}")
        try:
            await session.rollback()
        except Exception as rollback_error:
            error(f"回滚过程中出错: {str(rollback_error)}")
        raise
    finally:
        try:
            await session.close()
        except Exception as e:
            error(f"关闭会话时出错: {str(e)}")


async def init_db():
    """初始化数据库表结构"""
    try:
        engine = await create_db_engine()
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        info("数据库初始化成功")
    except Exception as e:
        error(f"数据库初始化失败: {str(e)}")
        raise


# 关闭数据库连接
async def close_db_connection():
    """关闭数据库连接"""
    global _engine
    if _engine is not None:
        try:
            await _engine.dispose()
            info("数据库连接已关闭")
        except Exception as e:
            error(f"关闭数据库连接时出错: {str(e)}")
        finally:
            _engine = None
